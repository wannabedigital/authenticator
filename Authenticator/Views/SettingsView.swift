import SwiftUI

struct SettingsView: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        @Bindable var lock = lock
        Form {
            Section {
                Toggle(isOn: Binding(get: { lock.isEnabled }, set: { newValue in
                    Task { await lock.setEnabled(newValue) }
                })) {
                    Text("Требовать \(lock.method.title) при открытии")
                    Text("Коды расшифровываются только после подтверждения.")
                }
                Picker("Блокировать после ухода из приложения", selection: $lock.timeout) {
                    ForEach(AppLock.Timeout.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!lock.isEnabled)
            } footer: {
                Text("При блокировке экрана и переходе Mac в сон приложение блокируется всегда.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
