import AppKit
import LocalAuthentication
import SwiftUI

/// Экран блокировки по образцу приложения «Пароли»: серый фон без заголовка окна,
/// иконка с кружком Touch ID, отпечаток проверяется прямо в окне.
///
/// Поле для пароля Mac, как в «Паролях», сторонним приложениям недоступно —
/// пароль вводится в системном окне по кнопке.
struct LockView: View {
    @Environment(AppLock.self) private var lock

    /// Новый контекст — новая попытка: после ошибки или отмены старый не переиспользуем.
    @State private var context = LAContext()
    @State private var isCheckingTouchID = false
    @State private var isUsingPassword = false
    /// Сколько раз подряд система отменила проверку сразу после старта.
    @State private var quickCancels = 0
    @State private var touchIDProblem: LocalizedStringKey?

    // Размеры и отступы сняты со скриншота «Паролей» (в точках).
    private let iconSide: CGFloat = 97        // плашка иконки — 78 pt
    private let badgeSide: CGFloat = 42       // кружок вокруг системного значка в 32 pt
    private let badgeOffset = CGSize(width: 14, height: 3)

    var body: some View {
        let canUseTouchID = lock.canUseTouchID
        let user = NSUserName()

        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: iconSide, height: iconSide)
                if canUseTouchID {
                    TouchIDView(authenticationContext: context, onAttached: startTouchID)
                        .id(ObjectIdentifier(context))
                        .frame(width: badgeSide, height: badgeSide)
                        .background {
                            Circle()
                                .fill(.background)
                                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                        }
                        .offset(badgeOffset)
                }
            }
            .padding(.bottom, 20)

            Text("Authenticator под защитой")
                .font(.title2.bold())
                .padding(.bottom, 12)

            Group {
                if canUseTouchID {
                    Text("Чтобы снять защиту, используйте Touch ID или введите пароль пользователя \(user).")
                } else {
                    Text("Чтобы снять защиту, введите пароль пользователя \(user).")
                }
            }
            .frame(maxWidth: 280)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 20)

            Button(action: unlockWithPassword) {
                Text("Ввести пароль…")
                    .frame(width: 156)
            }
            .controlSize(.large)
            .buttonStyle(.glass)
            .keyboardShortcut(.defaultAction)
            .disabled(lock.isAuthenticating)

            if let problem = touchIDProblem {
                Text(problem)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
            if let message = lock.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.top, 12)
            }
        }
        .multilineTextAlignment(.center)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: WindowLayout.minWidth, minHeight: WindowLayout.minHeight)
        // Как у «Паролей»: серый фон и под заголовком окна, без названия и разделителя.
        .background { Color.lockBackground.ignoresSafeArea() }
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        // Пока окно неактивно, система сама приостанавливает проверку. Если за это время
        // её отменили (Touch ID понадобился другому приложению), начинаем заново.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            quickCancels = 0
            if !isCheckingTouchID, !isUsingPassword { restartTouchID() }
        }
    }

    // MARK: Touch ID

    private func startTouchID() {
        guard lock.canUseTouchID, lock.isLocked, !isCheckingTouchID, !isUsingPassword else { return }
        let attempt = context
        let startedAt = Date.now
        isCheckingTouchID = true
        Task {
            let failure = await lock.unlockWithTouchID(attempt)
            isCheckingTouchID = false
            // Эту попытку уже заменили или остановили ради пароля — её итог не важен.
            guard attempt === context, !isUsingPassword else { return }
            switch failure {
            case nil, .userCancel:
                break
            case .systemCancel, .appCancel:
                // Сразу после появления окна система иногда отменяет проверку — пробуем ещё раз.
                let wasQuick = Date.now.timeIntervalSince(startedAt) < 1.5
                quickCancels = wasQuick ? quickCancels + 1 : 0
                guard NSApp.isActive, quickCancels <= 3 else { return }
                try? await Task.sleep(for: .milliseconds(300))
                if attempt === context { restartTouchID() }
            case .authenticationFailed:
                touchIDProblem = "Отпечаток не распознан. Попробуйте ещё раз."
                restartTouchID()
            case .biometryLockout:
                touchIDProblem = "Touch ID временно недоступен. Введите пароль Mac."
            default:
                touchIDProblem = "Не удалось проверить Touch ID. Введите пароль Mac."
            }
        }
    }

    /// Новый контекст пересоздаёт значок, и проверка стартует, когда он окажется в окне.
    private func restartTouchID() {
        context.invalidate()
        context = LAContext()
    }

    private func unlockWithPassword() {
        isUsingPassword = true
        context.invalidate()
        Task {
            await lock.unlock()
            isUsingPassword = false
            if lock.isLocked { restartTouchID() }
        }
    }
}

private extension Color {
    /// Фон экрана блокировки «Паролей» — #EDEDED; в тёмной теме — зеркально, чуть светлее чёрного.
    static let lockBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.17, alpha: 1)
            : NSColor(white: 237 / 255, alpha: 1)
    })
}
