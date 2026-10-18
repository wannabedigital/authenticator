import SwiftUI

@main
struct AuthenticatorApp: App {
    @State private var store: VaultStore
    @State private var lock: AppLock

    init() {
        #if BENCHMARK
        // Сборка замеров: `-benchmark-cards N` — N выдуманных аккаунтов вместо настоящего хранилища.
        // Блокировку на время замера выключает аргумент `-lock.enabled '<false/>'`.
        let count = UserDefaults.standard.integer(forKey: "benchmark-cards")
        let store = count > 0 ? VaultStore(benchmarkVault: .benchmark(accounts: count)) : VaultStore()
        #else
        let store = VaultStore()
        #endif
        _store = State(initialValue: store)
        _lock = State(initialValue: AppLock(store: store))
    }

    var body: some Scene {
        Window("Authenticator", id: "main") {
            ContentView()
                .environment(store)
                .environment(lock)
        }
        .defaultSize(width: 880, height: 580)
        .windowResizability(.contentMinSize)
        // Только значки и без меню «Значок и текст / Только значок / Только текст» по правому клику.
        .windowToolbarLabelStyle(fixed: .iconOnly)
        .commands { AppCommands(lock: lock) }

        Settings {
            SettingsView()
                .environment(lock)
        }
    }
}
