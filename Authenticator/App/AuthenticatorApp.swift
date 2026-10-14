import SwiftUI

@main
struct AuthenticatorApp: App {
    @State private var store: VaultStore
    @State private var lock: AppLock

    init() {
        let store = VaultStore()
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
        .commands { AppCommands(lock: lock) }

        Settings {
            SettingsView()
                .environment(lock)
        }
    }
}
