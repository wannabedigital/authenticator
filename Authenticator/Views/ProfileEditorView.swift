import SwiftUI

/// Создание или изменение профиля: название, цвет и значок.
struct ProfileEditorView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// `nil` — создаём новый профиль.
    let profile: Profile?
    let onCreate: (Profile.ID) -> Void

    @State private var name: String
    @State private var symbol: String
    @State private var color: ProfileColor

    init(profile: Profile?, suggestedColor: ProfileColor = .blue, onCreate: @escaping (Profile.ID) -> Void = { _ in }) {
        self.profile = profile
        self.onCreate = onCreate
        _name = State(initialValue: profile?.name ?? "")
        _symbol = State(initialValue: profile?.symbol ?? "person.fill")
        _color = State(initialValue: profile?.color ?? suggestedColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                ProfileIcon(symbol: symbol, color: color, size: 64)
                    .animation(.snappy, value: color)
                TextField("Название", text: $name, prompt: Text("Работа"))
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
            .padding(.top, 24)

            Form {
                Section("Цвет") {
                    colorPicker
                }
                Section("Значок") {
                    symbolPicker
                }
            }
            .formStyle(.grouped)

            SheetFooter(
                confirmTitle: profile == nil ? "Создать" : "Сохранить",
                canConfirm: !name.trimmed.isEmpty,
                onConfirm: save
            )
        }
        .frame(width: 420)
    }

    private var colorPicker: some View {
        HStack(spacing: 8) {
            ForEach(ProfileColor.allCases, id: \.self) { option in
                Button {
                    color = option
                } label: {
                    Circle()
                        .fill(option.color.gradient)
                        .frame(width: 20, height: 20)
                        .padding(3)
                        .overlay {
                            Circle().strokeBorder(.primary.opacity(color == option ? 0.6 : 0), lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .help(Text(option.title))
                .accessibilityLabel(Text(option.title))
                .accessibilityAddTraits(color == option ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var symbolPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(ProfileIcon.symbols, id: \.self) { option in
                Button {
                    symbol = option
                } label: {
                    Image(systemName: option)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(symbol == option ? Color.white : Color.secondary)
                        .background {
                            Circle().fill(symbol == option ? AnyShapeStyle(color.color.gradient) : AnyShapeStyle(.quaternary.opacity(0.5)))
                        }
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option)
                .accessibilityAddTraits(symbol == option ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        let name = name.trimmed
        guard !name.isEmpty else { return }
        if let profile {
            store.updateProfile(profile.id, name: name, symbol: symbol, color: color)
        } else {
            onCreate(store.addProfile(named: name, symbol: symbol, color: color))
        }
        dismiss()
    }
}
