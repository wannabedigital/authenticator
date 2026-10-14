import SwiftUI

@main
struct AuthenticatorApp: App {
    @State private var store = VaultStore()

    var body: some Scene {
        Window("Authenticator", id: "main") {
            ContentView()
                .environment(store)
        }
        .defaultSize(width: 880, height: 580)
        .windowResizability(.contentMinSize)
        .commands { AppCommands() }
    }
}
