import SwiftUI

struct AddAccountView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let profileID: Profile.ID

    @State private var link = ""
    @State private var linkError: String?
    @State private var issuer = ""
    @State private var name = ""
    @State private var secret = ""
    @State private var kind = OTPKind.totp
    @State private var algorithm = OTPAlgorithm.sha1
    @State private var digits = 6
    @State private var period = 30
    @State private var counter: UInt64 = 0

    private var decodedSecret: Data? { Base32.decode(secret) }
    private var isSecretInvalid: Bool { !secret.trimmed.isEmpty && decodedSecret == nil }
    private var canSave: Bool {
        decodedSecret?.isEmpty == false && !(issuer.trimmed.isEmpty && name.trimmed.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Ссылка", text: $link, prompt: Text("otpauth://totp/…"))
                } header: {
                    Text("Из ссылки")
                } footer: {
                    if let linkError {
                        Text(linkError).foregroundStyle(.red)
                    } else {
                        Text("Вставьте ссылку otpauth:// — поля ниже заполнятся сами.")
                    }
                }

                Section {
                    TextField("Сервис", text: $issuer, prompt: Text("GitHub"))
                    TextField("Аккаунт", text: $name, prompt: Text("me@example.com"))
                    TextField("Секретный ключ", text: $secret, prompt: Text("JBSW Y3DP EHPK 3PXP"))
                        .font(.body.monospaced())
                } header: {
                    Text("Аккаунт")
                } footer: {
                    if isSecretInvalid {
                        Text("Ключ должен состоять из латинских букв A–Z и цифр 2–7.").foregroundStyle(.red)
                    }
                }

                Section("Параметры") {
                    Picker("Тип", selection: $kind) {
                        Text("По времени (TOTP)").tag(OTPKind.totp)
                        Text("По счётчику (HOTP)").tag(OTPKind.hotp)
                    }
                    Picker("Алгоритм", selection: $algorithm) {
                        ForEach(OTPAlgorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Количество цифр", selection: $digits) {
                        ForEach(6...8, id: \.self) { Text("\($0)").tag($0) }
                    }
                    if kind == .totp {
                        Picker("Период", selection: $period) {
                            ForEach(Set([30, 60, period]).sorted(), id: \.self) { Text("\($0) секунд").tag($0) }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            SheetFooter(confirmTitle: "Добавить", canConfirm: canSave, onConfirm: save)
        }
        .frame(width: 460)
        .onChange(of: link) { applyLink() }
    }

    private func applyLink() {
        guard !link.trimmed.isEmpty else {
            linkError = nil
            return
        }
        do {
            let account = try OTPAuthURI.parse(link)
            issuer = account.issuer
            name = account.name
            secret = Base32.encode(account.secret)
            kind = account.kind
            algorithm = account.algorithm
            digits = account.digits
            period = account.period
            counter = account.counter
            linkError = nil
        } catch {
            linkError = error.localizedDescription
        }
    }

    private func save() {
        guard canSave, let secretData = decodedSecret else { return }
        let account = OTPAccount(
            issuer: issuer.trimmed,
            name: name.trimmed,
            secret: secretData,
            kind: kind,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter
        )
        store.addAccount(account, to: profileID)
        dismiss()
    }
}

/// Кнопки «Отмена» и подтверждения внизу листа.
struct SheetFooter: View {
    @Environment(\.dismiss) private var dismiss
    let confirmTitle: LocalizedStringKey
    let canConfirm: Bool
    let onConfirm: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button("Отмена", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(confirmTitle, action: onConfirm)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(!canConfirm)
        }
        .controlSize(.large)
        .padding([.horizontal, .bottom], 20)
    }
}
