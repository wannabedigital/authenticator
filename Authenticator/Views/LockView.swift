import SwiftUI

/// Экран блокировки в духе приложения «Пароли».
struct LockView: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            Text("Authenticator заблокирован")
                .font(.title2.weight(.semibold))
            Text("Используйте \(lock.method.title), чтобы увидеть коды.")
                .foregroundStyle(.secondary)

            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Разблокировать", systemImage: lock.method.symbol)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .keyboardShortcut(.defaultAction)
            .disabled(lock.isAuthenticating)
            .padding(.top, 10)

            if let message = lock.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .multilineTextAlignment(.center)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: WindowLayout.minWidth, minHeight: WindowLayout.minHeight)
    }
}
