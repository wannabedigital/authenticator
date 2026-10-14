import SwiftUI

/// Открытие резервной копии: пароль → выбор профилей → итог.
struct BackupImportView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let data: Data

    @State private var password = ""
    @State private var isOpening = false
    @State private var errorMessage: String?
    @State private var profiles: [Profile]?
    @State private var selected: Set<Profile.ID> = []
    @State private var result: (added: Int, skipped: Int)?

    var body: some View {
        Group {
            if let result {
                summary(result)
            } else if let profiles {
                profileStep(profiles)
            } else {
                passwordStep
            }
        }
        .frame(width: 440)
    }

    // MARK: Пароль

    private var passwordStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Открыть резервную копию")
                    .font(.title3.weight(.semibold))
                Text("Введите пароль, который задали при экспорте.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top], 20)

            Form {
                Section {
                    SecureField("Пароль", text: $password)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(action: open) {
                    if isOpening {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Открыть")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(password.isEmpty || isOpening)
            }
            .controlSize(.large)
            .padding([.horizontal, .bottom], 20)
        }
    }

    private func open() {
        isOpening = true
        errorMessage = nil
        let data = data
        let password = password
        Task {
            defer { isOpening = false }
            do {
                // PBKDF2 занимает доли секунды — не держим на нём интерфейс.
                let opened = try await Task.detached(priority: .userInitiated) {
                    try BackupFile.open(data, password: password)
                }.value
                selected = Set(opened.map(\.id))
                profiles = opened
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Профили

    private func profileStep(_ profiles: [Profile]) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Что импортировать")
                    .font(.title3.weight(.semibold))
                Text("Профили с таким же названием будут дополнены, а уже добавленные аккаунты — пропущены.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top], 20)

            Form {
                Section {
                    ForEach(profiles) { profile in
                        Toggle(isOn: Binding(
                            get: { selected.contains(profile.id) },
                            set: { if $0 { selected.insert(profile.id) } else { selected.remove(profile.id) } }
                        )) {
                            HStack(spacing: 8) {
                                ProfileIcon(profile: profile)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(profile.name)
                                    Text("Аккаунтов: \(profile.accounts.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 220)

            HStack {
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Импортировать") {
                    result = store.importProfiles(profiles.filter { selected.contains($0.id) })
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(selected.isEmpty)
            }
            .controlSize(.large)
            .padding([.horizontal, .bottom], 20)
        }
    }

    // MARK: Итог

    private func summary(_ result: (added: Int, skipped: Int)) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Импорт завершён")
                .font(.title3.weight(.semibold))
            Text("Добавлено аккаунтов: \(result.added). Уже были: \(result.skipped).")
                .foregroundStyle(.secondary)
            Button("Готово") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
