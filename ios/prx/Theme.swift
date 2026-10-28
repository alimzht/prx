import SwiftUI

// Цвета и шрифты приложения в одном месте. Тема всегда тёмная.
enum Theme {
    static let background = Color(hex: 0x0D1117)
    static let surface = Color(hex: 0x161B22)
    static let border = Color(hex: 0x2A313C)
    static let text = Color(hex: 0xE6EDF3)
    static let textMuted = Color(hex: 0x9AA4B2)
    static let accent = Color(hex: 0x4ADE80)
    static let accentDark = Color(hex: 0x13221A)
    static let danger = Color(hex: 0xF87171)
    static let warning = Color(hex: 0xFDBA74)

    /// Space Grotesk Bold (ios/prx/Fonts); масштабируется вместе с Dynamic Type.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("SpaceGrotesk-Bold", size: size, relativeTo: style)
    }

    /// Цвет громкости: обычный при 100%, зелёный громче, оранжевый тише.
    static func volumeColor(_ volume: Double) -> Color {
        let percent = Int((volume * 100).rounded())
        return percent == 100 ? text : (percent > 100 ? accent : warning)
    }

    // Приглушённые фоны аватаров и светлые оттенки букв к ним.
    private static let avatarPalette: [(Color, Color)] = [
        (Color(hex: 0x1F3A2B), Color(hex: 0x86EFAC)),
        (Color(hex: 0x1E3A5F), Color(hex: 0x93C5FD)),
        (Color(hex: 0x3B2A4D), Color(hex: 0xD8B4FE)),
        (Color(hex: 0x4A2A2A), Color(hex: 0xFCA5A5)),
        (Color(hex: 0x4A3B1F), Color(hex: 0xFCD34D)),
        (Color(hex: 0x1F4045), Color(hex: 0x67E8F9)),
    ]

    /// Стабильный выбор цвета по имени: hashValue меняется между запусками, поэтому сумма скаляров.
    static func avatarColors(for name: String) -> (background: Color, letter: Color) {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return avatarPalette[sum % avatarPalette.count]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Карточка/поле: фон surface и тонкая рамка.
struct SurfaceBackground: ViewModifier {
    var radius: CGFloat = 14
    var stroke: Color = Theme.border

    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(stroke, lineWidth: 1))
    }
}

extension View {
    func surface(radius: CGFloat = 14, stroke: Color = Theme.border) -> some View {
        modifier(SurfaceBackground(radius: radius, stroke: stroke))
    }
}

/// Круглый аватар с первой буквой имени и кольцом «говорит».
struct AvatarView: View {
    let name: String
    let isSpeaking: Bool
    var size: CGFloat = 84

    var body: some View {
        let colors = Theme.avatarColors(for: name)
        Text(name.first.map { String($0).uppercased() } ?? "?")
            .font(Theme.display(28))
            .foregroundColor(colors.letter)
            .frame(width: size, height: size)
            .background(Circle().fill(colors.background))
            // Кольцо 3pt с зазором 3pt вокруг аватара.
            .padding(6)
            .overlay(Circle().stroke(Theme.accent, lineWidth: 3).opacity(isSpeaking ? 1 : 0))
            .animation(.easeInOut(duration: 0.2), value: isSpeaking)
            .accessibilityHidden(true)
    }
}

#if DEBUG
enum PreviewData {
    static let participants: [ParticipantInfo] = [
        ParticipantInfo(id: "me", name: "Тимур", isSpeaking: false, isMuted: false, isLocal: true),
        ParticipantInfo(id: "d", name: "Даурен", isSpeaking: true, isMuted: false, isLocal: false, volume: 1.5),
        ParticipantInfo(id: "a", name: "Алия", isSpeaking: false, isMuted: false, isLocal: false, volume: 1),
        ParticipantInfo(id: "t", name: "Тимур К.", isSpeaking: false, isMuted: true, isLocal: false, volume: 0.8),
    ]
}
#endif
