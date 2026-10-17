import SwiftUI

/// Список аккаунтов, найденных в QR-кодах, перед добавлением в профиль.
struct ImportListView: View {
    struct MigrationProgress {
        var received: Int
        var total: Int
    }

    @Binding var accounts: [OTPAccount]
    let progress: MigrationProgress?

    var body: some View {
        Form {
            Section {
                ForEach(accounts) { account in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(account.title)
                            if let subtitle = account.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .lineLimit(1)
                        Spacer()
                        Button("Не добавлять", systemImage: "minus.circle.fill") {
                            accounts.removeAll { $0.id == account.id }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Не добавлять")
                    }
                }
            } header: {
                Text("Будут добавлены")
            } footer: {
                if let progress, progress.total > 1 {
                    if progress.received < progress.total {
                        Text("Получено QR-кодов: \(progress.received) из \(progress.total). Добавьте остальные, чтобы перенести все аккаунты.")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Получены все QR-коды: \(progress.total) из \(progress.total).")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .clippedAboveSheetFooter()
    }
}
