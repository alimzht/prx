import SwiftUI

struct JoinView: View {
    @ObservedObject var manager: AudioRoomManager
    @Binding var code: String
    @AppStorage("displayName") private var name = ""

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isConnecting: Bool { manager.state == .connecting }

    private var errorMessage: String? {
        if case .failed(let message) = manager.state { return message }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Room code", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: code) { newValue in
                            let filtered = String(newValue.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }.prefix(32))
                            if filtered != newValue { code = filtered }
                        }
                    TextField("Your name", text: $name)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        Task { await manager.join(code: trimmedCode, name: trimmedName) }
                    } label: {
                        HStack {
                            Text("Join")
                            if isConnecting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(trimmedCode.isEmpty || trimmedName.isEmpty || isConnecting)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("prx")
        }
    }
}
