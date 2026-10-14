import SwiftUI

/// QR-код `otpauth://` одного аккаунта — его понимают любые приложения-аутентификаторы.
struct AccountQRView: View {
    @Environment(\.dismiss) private var dismiss
    let account: OTPAccount

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(account.title)
                    .font(.title3.weight(.semibold))
                if let subtitle = account.subtitle {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
            }

            SecretQRCodeView(text: OTPAuthURI.string(for: account))

            Text("Отсканируйте в любом приложении-аутентификаторе. В коде сохранены все параметры аккаунта.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Label("Не делайте скриншотов: в коде ваш секретный ключ.", systemImage: "exclamationmark.shield")
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
        .frame(width: 440)
        .frame(minHeight: 520)
    }
}
