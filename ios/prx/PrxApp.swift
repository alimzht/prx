import SwiftUI

@main
struct PrxApp: App {
    @StateObject private var manager = AudioRoomManager()
    @State private var roomCode = ""

    var body: some Scene {
        WindowGroup {
            switch manager.state {
            case .connected, .reconnecting:
                RoomView(manager: manager, roomCode: roomCode)
            case .idle, .connecting, .failed:
                JoinView(manager: manager, code: $roomCode)
            }
        }
    }
}
