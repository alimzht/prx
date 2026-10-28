import SwiftUI

struct VolumeSheet: View {
    @ObservedObject var manager: AudioRoomManager
    let participantID: String
    @Environment(\.dismiss) private var dismiss

    // Слайдер работает в процентах 0…200.
    @State private var percent: Double = 100
    private let haptics = UIImpactFeedbackGenerator(style: .light)

    // Берём участника из менеджера, чтобы кольцо «говорит» обновлялось вживую.
    private var participant: ParticipantInfo? {
        manager.participants.first { $0.id == participantID }
    }

    var body: some View {
        ScrollView {
            if let participant {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        AvatarView(name: participant.name, isSpeaking: participant.isSpeaking)
                        Text(participant.name)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Theme.text)
                        Text("Громкость меняется только у тебя")
                            .font(.footnote)
                            .foregroundColor(Theme.textMuted)
                    }

                    Text("\(Int(percent))%")
                        .font(Theme.display(48, relativeTo: .largeTitle))
                        .foregroundColor(Theme.volumeColor(percent / 100))
                        .monospacedDigit()
                        .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            stepButton("minus", label: "Тише") { set(percent - 10) }
                            Slider(value: Binding(get: { percent }, set: { set($0) }), in: 0...200, step: 5)
                                .tint(Theme.accent)
                                .accessibilityLabel("Громкость \(participant.name)")
                                .accessibilityValue("\(Int(percent))%")
                            stepButton("plus", label: "Громче") { set(percent + 10) }
                        }
                        HStack {
                            Text("0%")
                            Spacer()
                            Text("100%")
                            Spacer()
                            Text("200%")
                        }
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 60)
                    }

                    HStack(spacing: 12) {
                        Button { set(100) } label: {
                            Text("Сбросить на 100%")
                                .font(.body.weight(.semibold))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
                        }
                        Button { dismiss() } label: {
                            Text("Готово")
                                .font(.body.weight(.semibold))
                                .foregroundColor(Theme.background)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(Theme.surface.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            percent = ((participant?.volume ?? 1) * 100).rounded()
            haptics.prepare()
        }
        // Участник вышел — закрываем лист.
        .onChange(of: participant == nil) { gone in
            if gone { dismiss() }
        }
    }

    private func stepButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.background))
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    private func set(_ value: Double) {
        let new = min(max(value, 0), 200)
        // Лёгкая вибрация при пересечении отметки 100%.
        if (percent < 100) != (new < 100) || (percent > 100) != (new > 100) { haptics.impactOccurred() }
        percent = new
        manager.setVolume(new / 100, for: participantID)
    }
}

#if DEBUG
struct VolumeSheet_Previews: PreviewProvider {
    static var previews: some View {
        Color.black
            .sheet(isPresented: .constant(true)) {
                VolumeSheet(manager: .preview(participants: PreviewData.participants), participantID: "d")
            }
            .preferredColorScheme(.dark)
    }
}
#endif
