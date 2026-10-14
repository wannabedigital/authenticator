import AppKit
import LocalAuthentication
import Observation

/// Блокировка приложения через Touch ID или пароль Mac.
///
/// Пока приложение заблокировано, хранилище не расшифровано и коды не находятся в памяти.
/// Приложение блокируется при блокировке экрана, уходе в сон и, по желанию,
/// через заданное время после переключения на другое приложение.
@MainActor
@Observable
final class AppLock {
    enum Timeout: Int, CaseIterable, Identifiable {
        case immediately = 0
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case oneHour = 3600
        case never = -1

        var id: Int { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .immediately: "Сразу"
            case .oneMinute: "Через 1 минуту"
            case .fiveMinutes: "Через 5 минут"
            case .fifteenMinutes: "Через 15 минут"
            case .oneHour: "Через 1 час"
            case .never: "Никогда"
            }
        }
    }

    private(set) var isEnabled: Bool
    var timeout: Timeout {
        didSet { defaults.set(timeout.rawValue, forKey: Keys.timeout) }
    }
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let store: VaultStore
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var resignedAt: Date?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    private enum Keys {
        static let enabled = "lock.enabled"
        static let timeout = "lock.timeout"
    }

    init(store: VaultStore) {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        self.store = store
        isEnabled = enabled
        isLocked = enabled
        timeout = (defaults.object(forKey: Keys.timeout) as? Int).flatMap(Timeout.init) ?? .fiveMinutes
        if !enabled { store.load() }
        observeSystemEvents()
    }

    /// «Touch ID» или «пароль» — в зависимости от того, что есть на этом Mac.
    var method: (title: LocalizedStringResource, symbol: String) {
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil), context.biometryType == .touchID {
            return ("Touch ID", "touchid")
        }
        return ("пароль", "lock.fill")
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        guard await authenticate(reason: String(localized: "показать коды двухфакторной аутентификации")) else { return }
        isLocked = false
        resignedAt = nil
        store.load()
    }

    func lock() {
        guard isEnabled, !isLocked else { return }
        isLocked = true
        store.unload()
    }

    /// Отключение защиты тоже требует подтверждения — иначе её мог бы снять кто угодно.
    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }
        if !enabled {
            guard await authenticate(reason: String(localized: "отключить блокировку приложения")) else { return }
        }
        isEnabled = enabled
        defaults.set(enabled, forKey: Keys.enabled)
    }

    private func authenticate(reason: String) async -> Bool {
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            errorMessage = nil
            return true
        } catch let error as LAError where [.userCancel, .appCancel, .systemCancel].contains(error.code) {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: Системные события

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.lock() }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.lock() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.lock() }
        observe(DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsLocked")) { $0.lock() }
        observe(NotificationCenter.default, NSApplication.didResignActiveNotification) { $0.applicationDidResignActive() }
        observe(NotificationCenter.default, NSApplication.didBecomeActiveNotification) { $0.applicationDidBecomeActive() }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping @MainActor (AppLock) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { handler(self) }
            }
        }
        observers.append((center, token))
    }

    private func applicationDidResignActive() {
        // Окно Touch ID — системное, на время проверки приложение теряет фокус.
        guard !isAuthenticating, !isLocked else { return }
        if timeout == .immediately {
            lock()
        } else {
            resignedAt = .now
        }
    }

    private func applicationDidBecomeActive() {
        guard !isAuthenticating else { return }
        if let resignedAt, timeout != .never, Date.now.timeIntervalSince(resignedAt) >= TimeInterval(timeout.rawValue) {
            lock()
        }
        resignedAt = nil
        if isLocked {
            Task { await unlock() }
        }
    }
}
