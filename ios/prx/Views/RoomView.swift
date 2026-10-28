import SwiftUI

struct RoomView: View {
    @ObservedObject var manager: AudioRoomManager
    @ObservedObject var store: RoomStore
    let roomCode: String

    // Обёртка, чтобы .sheet(item:) работал со строковым id.
    private struct Selection: Identifiable { let id: String }
    @State private var selected: Selection?
    @State private var isRenaming = false
    @State private var newRoomName = ""

    private var roomName: String { store.displayName(for: roomCode) }

    private var inviteText: String {
        "Заходи в голосовую комнату «\(roomName)» в prx: код \(roomCode) — \(store.inviteURL(for: roomCode))"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    status
                    if !manager.headphonesConnected { headphonesWarning }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                        ForEach(manager.participants) { participant in
                            ParticipantCard(participant: participant,
                                            micLevel: participant.isLocal ? manager.micLevel : nil) {
                                selected = Selection(id: participant.id)
                            }
                        }
                    }
                    Text("Нажми на человека, чтобы сделать его тише или громче")
                        .font(.footnote)
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            controls
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $selected) { selection in
            VolumeSheet(manager: manager, participantID: selection.id)
        }
        .alert("Название комнаты", isPresented: $isRenaming) {
            TextField("Например, Сквад", text: $newRoomName)
            Button("Сохранить") { store.rename(code: roomCode, to: newRoomName) }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Друзья увидят его, когда откроют твоё приглашение.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button {
                newRoomName = store.rooms.first { $0.code == roomCode }?.name ?? ""
                isRenaming = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(roomName)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                    Text(roomCode)
                        .font(Theme.display(26))
                        .tracking(3)
                        .foregroundColor(Theme.text)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(roomName), код \(roomCode)")
            .accessibilityHint("Переименовать комнату")
            .accessibilityAddTraits(.isButton)
            Spacer()
            ShareLink(item: inviteText) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Theme.accent)
                    Text("Пригласить")
                        .foregroundColor(Theme.text)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            }
        }
    }

    private var status: some View {
        let reconnecting = manager.state == .reconnecting
        return HStack(spacing: 8) {
            Circle()
                .fill(reconnecting ? Theme.warning : Theme.accent)
                .frame(width: 8, height: 8)
            Text(reconnecting ? "Переподключение…" : "\(Self.participantsLabel(manager.participants.count)) · игра не приглушается")
                .font(.footnote)
                .foregroundColor(Theme.textMuted)
        }
    }

    private var headphonesWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "headphones")
                .foregroundColor(Theme.warning)
                .accessibilityHidden(true)
            Text("Подключи наушники — без них микрофон будет слышать звук игры")
                .font(.footnote)
                .foregroundColor(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .surface(stroke: Theme.warning)
    }

    private var controls: some View {
        // 4 × 64 + 3 × 20 помещается в ширину iPhone SE.
        HStack(spacing: 20) {
            roundButton(icon: manager.isMicEnabled ? "mic.fill" : "mic.slash.fill",
                        title: "Микрофон",
                        iconColor: manager.isMicEnabled ? Theme.text : Theme.danger,
                        fill: Theme.surface,
                        a11y: manager.isMicEnabled ? "Выключить микрофон" : "Включить микрофон") {
                Task { await manager.setMicEnabled(!manager.isMicEnabled) }
            }
            roundButton(icon: manager.isDeafened ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        title: "Звук",
                        iconColor: manager.isDeafened ? Theme.danger : Theme.text,
                        fill: Theme.surface,
                        a11y: manager.isDeafened ? "Включить звук" : "Выключить звук") {
                manager.setDeafened(!manager.isDeafened)
            }
            roundButton(icon: "waveform",
                        title: "Шумодав",
                        iconColor: manager.isNoiseReductionEnabled ? Theme.accent : Theme.textMuted,
                        fill: Theme.surface,
                        a11y: manager.isNoiseReductionEnabled ? "Выключить шумоподавление" : "Включить шумоподавление") {
                Task { await manager.setNoiseReduction(!manager.isNoiseReductionEnabled) }
            }
            roundButton(icon: "rectangle.portrait.and.arrow.right",
                        title: "Выйти",
                        iconColor: Theme.background,
                        fill: Theme.danger,
                        a11y: "Выйти из комнаты") {
                Task { await manager.leave() }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private func roundButton(icon: String, title: String, iconColor: Color, fill: Color,
                             a11y: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(fill))
                    .overlay(Circle().stroke(Theme.border, lineWidth: fill == Theme.surface ? 1 : 0))
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .accessibilityAddTraits(.isButton)
    }

    /// 1 участник, 2 участника, 5 участников, 21 участник.
    static func participantsLabel(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        let word: String
        if mod10 == 1 && mod100 != 11 {
            word = "участник"
        } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            word = "участника"
        } else {
            word = "участников"
        }
        return "\(n) \(word)"
    }
}

#if DEBUG
struct RoomView_Previews: PreviewProvider {
    static var previews: some View {
        RoomView(manager: .preview(participants: PreviewData.participants), store: .preview(), roomCode: "K7Q2XP")
            .preferredColorScheme(.dark)
        RoomView(manager: .preview(participants: PreviewData.participants, isMicEnabled: false, headphonesConnected: false),
                 store: .preview(), roomCode: "K7Q2XP")
            .preferredColorScheme(.dark)
            .previewDisplayName("Без наушников")
        RoomView(manager: .preview(participants: PreviewData.participants), store: .preview(), roomCode: "K7Q2XP")
            .preferredColorScheme(.dark)
            .previewDevice("iPhone SE (3rd generation)")
            .previewDisplayName("iPhone SE")
    }
}
#endif
