import SwiftUI

struct RoomView: View {
    @ObservedObject var manager: AudioRoomManager
    let roomCode: String

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(roomCode)
                    .font(.title2.bold())
                    .accessibilityLabel("Room \(roomCode)")
                if manager.state == .reconnecting {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Reconnecting…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                if !manager.headphonesConnected {
                    Label("Connect headphones — without them your mic picks up game audio", systemImage: "headphones")
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding()

            List(manager.participants) { participant in
                ParticipantRow(participant: participant)
            }
            .listStyle(.plain)

            HStack(spacing: 32) {
                Button {
                    Task { await manager.setMicEnabled(!manager.isMicEnabled) }
                } label: {
                    Image(systemName: manager.isMicEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel(manager.isMicEnabled ? "Mute microphone" : "Unmute microphone")

                Button {
                    manager.setDeafened(!manager.isDeafened)
                } label: {
                    Image(systemName: manager.isDeafened ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel(manager.isDeafened ? "Undeafen" : "Deafen")

                Button(role: .destructive) {
                    Task { await manager.leave() }
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Leave room")
            }
            .padding()
        }
    }
}

private struct ParticipantRow: View {
    let participant: ParticipantInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .foregroundColor(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.green, lineWidth: participant.isSpeaking ? 3 : 0))
                .animation(.easeInOut(duration: 0.15), value: participant.isSpeaking)

            Text(participant.isLocal ? "\(participant.name) (you)" : participant.name)

            Spacer()

            if participant.isMuted {
                Image(systemName: "mic.slash.fill")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Muted")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(participant.isSpeaking ? "Speaking" : "")
    }
}
