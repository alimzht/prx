import SwiftUI

@main
struct PrxApp: App {
    @StateObject private var manager = AudioRoomManager()
    @StateObject private var store = RoomStore()
    @State private var roomCode = ""
    @AppStorage("displayName") private var name = ""

    var body: some Scene {
        WindowGroup {
            Group {
                switch manager.state {
                case .connected, .reconnecting:
                    RoomView(manager: manager, store: store, roomCode: roomCode)
                case .idle, .connecting, .failed:
                    HomeView(manager: manager, store: store, code: $roomCode)
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL(perform: openInvite)
            // Каждая комната, в которую удалось зайти, попадает в «Мои комнаты».
            .onChange(of: manager.state) { state in
                if state == .connected { store.touch(code: roomCode) }
            }
        }
    }

    /// prx://join/<CODE>?name=<название>: сохраняем комнату и сразу заходим, если имя уже есть.
    private func openInvite(_ url: URL) {
        guard url.scheme == "prx", url.host == "join",
              let code = url.pathComponents.dropFirst().first?.uppercased(),
              code.count == 6, code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return }
        let roomName = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "name" }?.value
        // Своё название не затираем: имя из ссылки берём только для новой комнаты.
        if !store.rooms.contains(where: { $0.code == code }) {
            store.touch(code: code, name: roomName ?? "")
        }
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
