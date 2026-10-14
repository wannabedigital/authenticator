import AppKit
import SwiftUI

/// Перенос аккаунтов в Google Authenticator через QR-коды формата `otpauth-migration://`.
struct ExportView: View {
    @Environment(VaultStore.self) private var store
    @Environment(AppLock.self) private var lock
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Set<OTPAccount.ID> = []
    /// `nil` — выбор аккаунтов, иначе — показ QR-кодов.
    @State private var codes: [(accounts: [OTPAccount], link: String)]?
    @State private var page = 0
    @State private var isAppActive = NSApp.isActive

    private var compatibleIDs: Set<OTPAccount.ID> {
        Set(store.profiles.flatMap(\.accounts).filter { GoogleMigration.incompatibility(of: $0) == nil }.map(\.id))
    }

    var body: some View {
        Group {
            if let codes {
                codeStep(codes)
            } else {
                selectionStep
            }
        }
        .frame(width: 480)
        .frame(minHeight: 560)
        .onAppear { selection = compatibleIDs }
        // Секреты не держим на экране, пока вы в другом приложении.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in isAppActive = false }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in isAppActive = true }
    }

    // MARK: Выбор аккаунтов

    private var selectionStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Перенос в Google Authenticator")
                    .font(.title3.weight(.semibold))
                Text("Выберите аккаунты. Недоступны те, чьи коды Google Authenticator показал бы неверно.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top], 20)

            Form {
                ForEach(store.profiles.filter { !$0.accounts.isEmpty }) { profile in
                    Section {
                        ForEach(profile.accounts) { account in
                            row(for: account)
                        }
                    } header: {
                        Label {
                            Text(profile.name)
                        } icon: {
                            ProfileIcon(profile: profile, size: 18)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(selection.isEmpty ? "Выбрать все" : "Снять выбор") {
                    selection = selection.isEmpty ? compatibleIDs : []
                }
                .disabled(compatibleIDs.isEmpty)
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Показать QR-коды", action: showCodes)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .disabled(selection.isEmpty)
            }
            .controlSize(.large)
            .padding([.horizontal, .bottom], 20)
        }
    }

    private func row(for account: OTPAccount) -> some View {
        let issue = GoogleMigration.incompatibility(of: account)
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

    private func showCodes() {
        Task {
            guard await lock.confirmIdentity(reason: String(localized: "показать секретные ключи для переноса")) else { return }
            let accounts = store.profiles.flatMap(\.accounts).filter { selection.contains($0.id) }
            page = 0
            codes = GoogleMigration.encode(accounts)
        }
    }

    // MARK: QR-коды

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

            Group {
                if isAppActive, let image = QRCodeImage.make(code.link) {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .background(.white, in: .rect(cornerRadius: 18))
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.quaternary)
                        .overlay {
                            Label("Код скрыт, пока приложение неактивно", systemImage: "eye.slash")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 300, height: 300)

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
