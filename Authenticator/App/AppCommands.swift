import SwiftUI

/// Действия активного окна для пунктов меню. `nil` — пункт недоступен.
extension FocusedValues {
    var addAccountAction: (() -> Void)? {
        get { self[AddAccountActionKey.self] }
        set { self[AddAccountActionKey.self] = newValue }
    }

    var newProfileAction: (() -> Void)? {
        get { self[NewProfileActionKey.self] }
        set { self[NewProfileActionKey.self] = newValue }
    }
}

private struct AddAccountActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct NewProfileActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

/// Пункты меню «Файл» с горячими клавишами.
struct AppCommands: Commands {
    let lock: AppLock
    @FocusedValue(\.addAccountAction) private var addAccount
    @FocusedValue(\.newProfileAction) private var newProfile

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Новый аккаунт") { addAccount?() }
                .keyboardShortcut("n")
                .disabled(addAccount == nil)
            Button("Новый профиль") { newProfile?() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(newProfile == nil)
        }
        CommandGroup(after: .newItem) {
            Divider()
            Button("Заблокировать") { lock.lock() }
                .keyboardShortcut("l", modifiers: [.command, .control])
                .disabled(!lock.isEnabled || lock.isLocked)
        }
    }
}
