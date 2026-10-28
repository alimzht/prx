import SwiftUI

@main
struct PrxApp: App {
    @StateObject private var manager = AudioRoomManager()
    @State private var roomCode = ""
    @AppStorage("displayName") private var name = ""

    var body: some Scene {
        WindowGroup {
            Group {
                switch manager.state {
                case .connected, .reconnecting:
                    RoomView(manager: manager, roomCode: roomCode)
                case .idle, .connecting, .failed:
                    HomeView(manager: manager, code: $roomCode)
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL(perform: openInvite)
        }
    }

    /// prx://join/<CODE>: сразу заходим, если имя уже есть; иначе подставляем код в поле.
    private func openInvite(_ url: URL) {
        guard url.scheme == "prx", url.host == "join",
              let code = url.pathComponents.dropFirst().first?.uppercased(),
              code.count == 6, code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return }
        switch manager.state {
        case .idle, .failed:
            roomCode = code
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Task { await manager.join(code: code, name: trimmed) }
            }
        case .connecting, .connected, .reconnecting:
            break // уже в комнате — ссылку игнорируем
        }
    }
}
