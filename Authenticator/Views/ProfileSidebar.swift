import SwiftUI

struct ProfileSidebar: View {
    @Environment(VaultStore.self) private var store
    @Binding var selection: Profile.ID?

    @State private var isEditingName = false
    /// `nil` — создаём новый профиль, иначе переименовываем существующий.
    @State private var editedProfileID: Profile.ID?
    @State private var draftName = ""
    @State private var profileToDelete: Profile?

    var body: some View {
        List(selection: $selection) {
            Section("Профили") {
                ForEach(store.profiles) { profile in
                    Label(profile.name, systemImage: "person.crop.circle")
                        .badge(profile.accounts.count)
                        .contextMenu {
                            Button("Переименовать…", systemImage: "pencil") { beginRename(profile) }
                            Divider()
                            Button("Удалить…", systemImage: "trash", role: .destructive) { profileToDelete = profile }
                                .disabled(store.profiles.count < 2)
                        }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        .safeAreaInset(edge: .bottom) {
            Button("Новый профиль", systemImage: "plus", action: beginCreate)
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .alert(editedProfileID == nil ? "Новый профиль" : "Переименовать профиль", isPresented: $isEditingName) {
            TextField("Название", text: $draftName)
            Button("Отмена", role: .cancel) {}
            Button(editedProfileID == nil ? "Создать" : "Сохранить", action: commitName)
                .disabled(draftName.trimmed.isEmpty)
        }
        .confirmationDialog(
            "Удалить профиль «\(profileToDelete?.name ?? "")»?",
            isPresented: Binding(get: { profileToDelete != nil }, set: { if !$0 { profileToDelete = nil } }),
            titleVisibility: .visible,
            presenting: profileToDelete
        ) { profile in
            Button("Удалить профиль", role: .destructive) { store.deleteProfile(profile.id) }
        } message: { profile in
            if profile.accounts.isEmpty {
                Text("Профиль пуст.")
            } else {
                Text("Вместе с ним будут удалены аккаунты (\(profile.accounts.count)). Это действие нельзя отменить.")
            }
        }
    }

    private func beginCreate() {
        editedProfileID = nil
        draftName = ""
        isEditingName = true
    }

    private func beginRename(_ profile: Profile) {
        editedProfileID = profile.id
        draftName = profile.name
        isEditingName = true
    }

    private func commitName() {
        let name = draftName.trimmed
        guard !name.isEmpty else { return }
        if let editedProfileID {
            store.renameProfile(editedProfileID, to: name)
        } else {
            selection = store.addProfile(named: name)
        }
    }
}
