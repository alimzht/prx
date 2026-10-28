import SwiftUI

struct HomeView: View {
    @ObservedObject var manager: AudioRoomManager
    @Binding var code: String
    @AppStorage("displayName") private var name = ""

    // Какая кнопка нажата — на ней крутится индикатор.
    @State private var pending: Action?
    private enum Action { case create, join }

    // Без 0/O/1/I, чтобы код было легко продиктовать.
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isConnecting: Bool { manager.state == .connecting }
    private var canCreate: Bool { !trimmedName.isEmpty && !isConnecting }
    private var canJoin: Bool { canCreate && code.count == 6 }

    private var errorMessage: String? {
        if case .failed(let message) = manager.state { return message }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                nameField
                createButton
                divider
                codeRow
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(Theme.danger)
                }
                linkHint
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .onChange(of: manager.state) { state in
            if state != .connecting { pending = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.background)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                Text("prx")
                    .font(Theme.display(30))
                    .foregroundColor(Theme.text)
            }
            Text("Голосовой чат для игры с друзьями. Звук игры не приглушается.")
                .font(.subheadline)
                .foregroundColor(Theme.textMuted)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Твоё имя")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Theme.textMuted)
            TextField("", text: $name)
                .textContentType(.nickname)
                .autocorrectionDisabled()
                .foregroundColor(Theme.text)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .surface()
                .accessibilityLabel("Твоё имя")
                .onChange(of: name) { value in
                    if value.count > 20 { name = String(value.prefix(20)) }
                }
        }
    }

    private var createButton: some View {
        Button {
            let newCode = String((0..<6).map { _ in Self.alphabet.randomElement()! })
            code = newCode
            join(newCode, as: .create)
        } label: {
            HStack(spacing: 8) {
                if pending == .create {
                    ProgressView().tint(Theme.background)
                } else {
                    Image(systemName: "plus")
                }
                Text("Создать комнату")
            }
            .font(.body.weight(.semibold))
            .foregroundColor(Theme.background)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!canCreate)
        .opacity(canCreate ? 1 : 0.5)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.border).frame(height: 1)
            Text("или войди по коду")
                .font(.footnote)
                .foregroundColor(Theme.textMuted)
                .fixedSize()
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    private var codeRow: some View {
        HStack(spacing: 12) {
            TextField("", text: $code, prompt: Text("КОД").foregroundColor(Theme.textMuted))
                .font(Theme.display(18, relativeTo: .body))
                .tracking(3)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundColor(Theme.text)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .surface()
                .accessibilityLabel("Код комнаты")
                .onChange(of: code) { value in
                    // Только A–Z и 0–9, заглавные, максимум 6.
                    let cleaned = String(value.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(6))
                    if cleaned != value { code = cleaned }
                }

            Button {
                join(code, as: .join)
            } label: {
                Group {
                    if pending == .join {
                        ProgressView().tint(Theme.accent)
                    } else {
                        Text("Войти")
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 20)
                .frame(minHeight: 52)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.accent, lineWidth: 1))
            }
            .disabled(!canJoin)
            .opacity(canJoin ? 1 : 0.5)
        }
    }

    private var linkHint: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "link")
                .foregroundColor(Theme.accent)
                .accessibilityHidden(true)
            Text("Друг прислал ссылку? Просто открой её — приложение само зайдёт в комнату.")
                .font(.footnote)
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surface(radius: 20)
    }

    private func join(_ roomCode: String, as action: Action) {
        name = trimmedName
        pending = action
        Task { await manager.join(code: roomCode, name: trimmedName) }
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(manager: .preview(state: .idle), code: .constant(""))
            .preferredColorScheme(.dark)
        HomeView(manager: .preview(state: .failed("Не удалось подключиться")), code: .constant("K7Q2XP"))
            .preferredColorScheme(.dark)
            .previewDisplayName("Ошибка")
    }
}
#endif
