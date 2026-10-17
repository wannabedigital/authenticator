import SwiftUI

struct ProfileSidebar: View {
    @Environment(VaultStore.self) private var store
    @Environment(AppLock.self) private var lock
    @Binding var selection: Profile.ID?
    @Binding var search: SearchState

    @State private var isCreatingProfile = false
    @State private var profileToEdit: Profile?
    @State private var profileToDelete: Profile?

    var body: some View {
        List(selection: $selection) {
            Section("Профили") {
                ForEach(filteredProfiles) { profile in
                    Label {
                        Text(profile.name)
                    } icon: {
                        ProfileIcon(profile: profile)
                    }
                    .badge(profile.accounts.count)
                    .contextMenu {
                        Button("Изменить…", systemImage: "pencil") { profileToEdit = profile }
                        Divider()
                        Button("Удалить…", systemImage: "trash", role: .destructive) { profileToDelete = profile }
                            .disabled(store.profiles.count < 2)
                    }
                }
                if filteredProfiles.isEmpty {
                    Text("Ничего не найдено")
                        .foregroundStyle(.secondary)
                        .selectionDisabled()
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: WindowLayout.sidebarMaxWidth)
        .onChange(of: lock.isClosingSheets) { _, closing in
            guard closing else { return }
            isCreatingProfile = false
            profileToEdit = nil
            profileToDelete = nil
        }
        .safeAreaBar(edge: .top) {
            if search.isPresented {
                SearchField(text: $search.query, prompt: String(localized: "Поиск профилей"), focusRequest: search.focusRequest) {
                    withAnimation(SearchState.animation) { search.dismiss() }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Новый профиль", systemImage: "plus") { isCreatingProfile = true }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .focusedSceneValue(\.newProfileAction) { isCreatingProfile = true }
        .sheet(isPresented: $isCreatingProfile) {
            ProfileEditorView(profile: nil, suggestedColor: nextColor) { selection = $0 }
        }
        .sheet(item: $profileToEdit) { profile in
            ProfileEditorView(profile: profile)
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

    private var filteredProfiles: [Profile] {
        let query = search.query.trimmed
        guard !query.isEmpty else { return store.profiles }
        return store.profiles.filter { $0.name.localizedStandardContains(query) }
    }

    /// Новому профилю предлагаем цвет, которого ещё нет, чтобы профили сразу различались.
    private var nextColor: ProfileColor {
        let used = Set(store.profiles.map(\.color))
        let palette: [ProfileColor] = [.blue, .orange, .green, .purple, .pink, .teal, .red, .indigo, .yellow, .mint, .brown, .cyan, .gray]
        return palette.first { !used.contains($0) } ?? .blue
    }
}
