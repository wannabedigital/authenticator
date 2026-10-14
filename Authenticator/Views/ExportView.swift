import SwiftUI

/// Экспорт выбранных аккаунтов: зашифрованным файлом для Authenticator
/// или QR-кодами формата `otpauth-migration://` для Google Authenticator.
struct ExportView: View {
    enum Method: Hashable {
        case file
        case googleAuthenticator
    }

    private enum Step {
        case selection
        case password
        case codes([(accounts: [OTPAccount], link: String)])
    }

    @Environment(VaultStore.self) private var store
    @Environment(AppLock.self) private var lock
    @Environment(\.dismiss) private var dismiss

    @State private var method = Method.file
    @State private var step = Step.selection
    @State private var selection: Set<OTPAccount.ID> = []
    @State private var collapsedProfiles: Set<Profile.ID> = []
    @State private var page = 0

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isSealing = false
    @State private var document: BackupDocument?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private func isSelectable(_ account: OTPAccount) -> Bool {
        method == .file || GoogleMigration.incompatibility(of: account) == nil
    }

    private var selectableIDs: Set<OTPAccount.ID> {
        Set(store.profiles.flatMap(\.accounts).filter(isSelectable).map(\.id))
    }

    var body: some View {
        Group {
            switch step {
            case .selection: selectionStep
            case .password: passwordStep
            case .codes(let codes): codeStep(codes)
            }
        }
        .frame(width: 480)
        .frame(minHeight: 560)
        .onAppear { selection = selectableIDs }
        .onChange(of: method) { selection.formIntersection(selectableIDs) }
        .alert("Не удалось сохранить файл", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Выбор аккаунтов

    private var selectionStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Экспорт")
                    .font(.title3.weight(.semibold))
                Picker("Способ", selection: $method) {
                    Text("Файл Authenticator").tag(Method.file)
                    Text("Google Authenticator").tag(Method.googleAuthenticator)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Group {
                    switch method {
                    case .file:
                        Text("Зашифрованный паролем файл со всеми профилями и параметрами — для переноса в Authenticator на другом Mac или резервной копии.")
                    case .googleAuthenticator:
                        Text("QR-коды для Google Authenticator на iPhone. Недоступны аккаунты, чьи коды Google Authenticator показал бы неверно.")
                    }
                }
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top], 20)

            Form {
                ForEach(store.profiles.filter { !$0.accounts.isEmpty }) { profile in
                    // Заголовок профиля — первая строка рамки: её верх закреплён,
                    // и при сворачивании рамка сжимается только снизу.
                    Section {
                        header(for: profile)
                        if !collapsedProfiles.contains(profile.id) {
                            ForEach(profile.accounts) { account in
                                row(for: account)
                                    .padding(.leading, 18)
                                    .transition(.opacity)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(selection.isEmpty ? "Выбрать все" : "Снять выбор") {
                    selection = selection.isEmpty ? selectableIDs : []
                }
                .disabled(selectableIDs.isEmpty)
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Group {
                    switch method {
                    case .file: Button("Далее") { step = .password }
                    case .googleAuthenticator: Button("Показать QR-коды", action: showCodes)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(selection.isEmpty)
            }
            .controlSize(.large)
            .padding([.horizontal, .bottom], 20)
        }
    }

    /// Шеврон сворачивает профиль, счётчик и галочка справа относятся ко всем доступным аккаунтам профиля.
    private func header(for profile: Profile) -> some View {
        let ids = Set(profile.accounts.filter(isSelectable).map(\.id))
        let isCollapsed = collapsedProfiles.contains(profile.id)
        return HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isCollapsed { collapsedProfiles.remove(profile.id) } else { collapsedProfiles.insert(profile.id) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    ProfileIcon(profile: profile, size: 20)
                    Text(profile.name)
                        .font(.headline)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(profile.name))
            .accessibilityHint(isCollapsed ? Text("Развернуть") : Text("Свернуть"))

            Spacer()

            Text("\(ids.intersection(selection).count) из \(ids.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Toggle("Выбрать все в профиле", isOn: Binding(
                get: { !ids.isEmpty && ids.isSubset(of: selection) },
                set: { if $0 { selection.formUnion(ids) } else { selection.subtract(ids) } }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(ids.isEmpty)
            .help("Выбрать все в профиле")
        }
    }

    private func row(for account: OTPAccount) -> some View {
        let issue = method == .googleAuthenticator ? GoogleMigration.incompatibility(of: account) : nil
        return Toggle(isOn: Binding(
            get: { selection.contains(account.id) },
            set: { if $0 { selection.insert(account.id) } else { selection.remove(account.id) } }
        )) {
            Text(account.title)
            if let issue {
                Text(reason(issue, for: account))
            } else if let subtitle = account.subtitle {
                Text(subtitle)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(issue != nil)
    }

    private func reason(_ issue: GoogleMigration.Incompatibility, for account: OTPAccount) -> LocalizedStringKey {
        switch issue {
        case .algorithm: "Алгоритм \(account.algorithm.rawValue) — Google Authenticator поддерживает только SHA1"
        case .digits: "Цифр в коде: \(account.digits) — Google Authenticator показывает только 6"
        case .period: "Период \(account.period) с — Google Authenticator поддерживает только 30 с"
        }
    }

    /// Выбранные аккаунты в порядке профилей.
    private var selectedAccounts: [OTPAccount] {
        store.profiles.flatMap(\.accounts).filter { selection.contains($0.id) }
    }

    /// Профили только с выбранными аккаунтами — для файла.
    private var selectedProfiles: [Profile] {
        store.profiles.compactMap { profile in
            let accounts = profile.accounts.filter { selection.contains($0.id) }
            guard !accounts.isEmpty else { return nil }
            var copy = profile
            copy.accounts = accounts
            return copy
        }
    }

    // MARK: Файл

    /// `nil` — пароль подходит.
    private var passwordProblem: LocalizedStringKey? {
        if password.count < 8 { return "Пароль должен быть не короче 8 символов" }
        if confirmation != password { return "Пароли не совпадают" }
        return nil
    }

    private var passwordStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Пароль для файла")
                    .font(.title3.weight(.semibold))
                Text("Файл будет зашифрован этим паролем. Без него файл не открыть, а восстановить пароль нельзя.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top], 20)

            Form {
                Section {
                    SecureField("Пароль", text: $password)
                    SecureField("Повторите пароль", text: $confirmation)
                } footer: {
                    if let passwordProblem, !password.isEmpty {
                        Text(passwordProblem).foregroundStyle(.orange)
                    } else {
                        Text("Аккаунтов в файле: \(selection.count)")
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Назад") { step = .selection }
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(action: saveFile) {
                    if isSealing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Сохранить файл…")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(passwordProblem != nil || isSealing)
            }
            .controlSize(.large)
            .padding([.horizontal, .bottom], 20)
        }
        .fileExporter(
            isPresented: $isSaving,
            document: document,
            contentType: BackupFile.contentType,
            defaultFilename: "Authenticator " + Date.now.formatted(.iso8601.year().month().day())
        ) { result in
            switch result {
            case .success:
                dismiss()
            case .failure(let error as CocoaError) where error.code == .userCancelled:
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveFile() {
        Task {
            guard await lock.confirmIdentity(reason: String(localized: "сохранить резервную копию с секретными ключами")) else { return }
            isSealing = true
            defer { isSealing = false }
            let profiles = selectedProfiles
            let password = password
            do {
                // PBKDF2 занимает доли секунды — не держим на нём интерфейс.
                let data = try await Task.detached(priority: .userInitiated) {
                    try BackupFile.seal(profiles, password: password)
                }.value
                document = BackupDocument(data: data)
                isSaving = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: QR-коды для Google Authenticator

    private func showCodes() {
        Task {
            guard await lock.confirmIdentity(reason: String(localized: "показать секретные ключи для переноса")) else { return }
            page = 0
            step = .codes(GoogleMigration.encode(selectedAccounts))
        }
    }

    private func codeStep(_ codes: [(accounts: [OTPAccount], link: String)]) -> some View {
        let code = codes[min(page, codes.count - 1)]
        return VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Отсканируйте в Google Authenticator")
                    .font(.title3.weight(.semibold))
                Text("На iPhone откройте меню, выберите перенос аккаунтов, затем импорт, и наведите камеру на код.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            SecretQRCodeView(text: code.link)

            Text(code.accounts.map(\.title).joined(separator: ", "))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if codes.count > 1 {
                HStack(spacing: 16) {
                    Button("Предыдущий код", systemImage: "chevron.left") { page -= 1 }
                        .disabled(page == 0)
                    Text("QR-код \(page + 1) из \(codes.count)")
                        .monospacedDigit()
                    Button("Следующий код", systemImage: "chevron.right") { page += 1 }
                        .disabled(page == codes.count - 1)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
            }

            Spacer(minLength: 0)

            HStack {
                Label("Не делайте скриншотов: в кодах ваши секретные ключи.", systemImage: "exclamationmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
        }
        .padding(20)
    }
}
