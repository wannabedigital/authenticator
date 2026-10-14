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

    @State private var dropStatus: QRDropZone.Status?
    /// Аккаунты из QR-кодов. Если список не пуст, лист показывает его вместо формы.
    @State private var pending: [OTPAccount] = []
    @State private var migrationParts: Set<Int> = []
    @State private var migrationTotal = 0

    private var decodedSecret: Data? { Base32.decode(secret) }
    private var isSecretInvalid: Bool { !secret.trimmed.isEmpty && decodedSecret == nil }
    private var canSave: Bool {
        decodedSecret?.isEmpty == false && !(issuer.trimmed.isEmpty && name.trimmed.isEmpty)
    }

    private var existingSecrets: Set<Data> {
        Set(store.profile(withID: profileID)?.accounts.map(\.secret) ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            QRDropZone(status: dropStatus, onImport: importItems)
                .padding([.horizontal, .top], 20)

            if pending.isEmpty {
                manualForm
            } else {
                ImportListView(
                    accounts: $pending,
                    progress: migrationTotal > 1
                        ? ImportListView.MigrationProgress(received: migrationParts.count, total: migrationTotal)
                        : nil
                )
            }

            if pending.isEmpty {
                SheetFooter(confirmTitle: "Добавить", canConfirm: canSave, onConfirm: save)
            } else {
                SheetFooter(confirmTitle: "Добавить аккаунты: \(pending.count)", canConfirm: true, onConfirm: savePending)
            }
        }
        .frame(width: 480)
        .frame(minHeight: 600)
        .onChange(of: link) { applyLink() }
    }

    private var manualForm: some View {
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
    }

    private func applyLink() {
        guard !link.trimmed.isEmpty else {
            linkError = nil
            return
        }
        if GoogleMigration.isMigrationLink(link) {
            var scan = ImportScan()
            scan.add(payload: link)
            link = ""
            apply(scan)
            return
        }
        do {
            fill(with: try OTPAuthURI.parse(link))
            linkError = nil
        } catch {
            linkError = error.localizedDescription
        }
    }

    private func fill(with account: OTPAccount) {
        issuer = account.issuer
        name = account.name
        secret = Base32.encode(account.secret)
        kind = account.kind
        algorithm = account.algorithm
        digits = account.digits
        period = account.period
        counter = account.counter
    }

    // MARK: Импорт из QR-кодов

    private func importItems(_ items: [ImportItem]) async {
        guard !items.isEmpty else {
            dropStatus = .failure("В буфере обмена нет изображения.")
            return
        }
        dropStatus = .scanning
        apply(await ImportScan.scan(items))
    }

    private func apply(_ scan: ImportScan) {
        guard !scan.accounts.isEmpty else {
            dropStatus = scan.isMigration
                ? .failure("В этом QR-коде нет поддерживаемых аккаунтов.")
                : .failure(scan.failureMessage)
            return
        }

        // Обычный QR-код с сайта — просто заполняем форму, чтобы можно было проверить поля.
        if !scan.isMigration, scan.accounts.count == 1, pending.isEmpty {
            let account = scan.accounts[0]
            fill(with: account)
            dropStatus = existingSecrets.contains(account.secret)
                ? .failure("«\(account.title)» уже есть в этом профиле.")
                : .success("Распознано: \(account.title)")
            return
        }

        for batch in scan.batches {
            migrationParts.insert(batch.index)
            migrationTotal = max(migrationTotal, batch.size)
        }

        var known = existingSecrets.union(pending.map(\.secret))
        var skipped = 0
        for account in scan.accounts {
            if known.insert(account.secret).inserted {
                pending.append(account)
            } else {
                skipped += 1
            }
        }
        let added = scan.accounts.count - skipped
        dropStatus = switch (added, skipped) {
        case (0, _): .failure("Эти аккаунты уже добавлены.")
        case (_, 0): .success("Найдено аккаунтов: \(added)")
        default: .success("Найдено аккаунтов: \(added), уже были: \(skipped)")
        }
    }

    private func savePending() {
        store.addAccounts(pending, to: profileID)
        dismiss()
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
