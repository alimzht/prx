import SwiftUI

struct ParticipantCard: View {
    let participant: ParticipantInfo
    let onTap: () -> Void

    private var percent: Int { Int((participant.volume * 100).rounded()) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                AvatarView(name: participant.name, isSpeaking: participant.isSpeaking)
                    .overlay(alignment: .bottomTrailing) {
                        if participant.isMuted {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.background)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Theme.danger))
                                .offset(x: -4, y: -4)
                        }
                    }

                Text(participant.isLocal ? "\(participant.name) (ты)" : participant.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)

                subtitle
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 10)
            .background(participant.isSpeaking ? Theme.accentDark : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(participant.isSpeaking ? Theme.accent : Theme.border, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: participant.isSpeaking)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!participant.isLocal) // свою громкость не меняем; .disabled приглушил бы карточку
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(participant.isLocal ? "\(participant.name), ты" : participant.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(participant.isLocal ? "" : "Открыть громкость")
    }

    @ViewBuilder
    private var subtitle: some View {
        VStack(spacing: 4) {
            if participant.isLocal {
                Text("Твой микрофон")
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
            } else if percent == 100 {
                Text("100%")
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
            } else {
                Text("\(percent)%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent))
            }
            if participant.isMuted {
                Text("микрофон выкл.")
                    .font(.caption)
                    .foregroundColor(Theme.danger)
            }
        }
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if participant.isSpeaking { parts.append("говорит") }
        if participant.isMuted { parts.append("микрофон выключен") }
        if !participant.isLocal { parts.append("громкость \(percent)%") }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
struct ParticipantCard_Previews: PreviewProvider {
    static var previews: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
            ForEach(PreviewData.participants) { ParticipantCard(participant: $0, onTap: {}) }
        }
        .padding(20)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}
#endif
