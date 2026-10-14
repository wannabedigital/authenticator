import SwiftUI

struct ContentView: View {
    @Environment(VaultStore.self) private var store
    @Environment(AppLock.self) private var lock
    @State private var selection: Profile.ID?
    @State private var searchText = ""
    @State private var isAddingAccount = false

    var body: some View {
        if lock.isLocked || !store.isLoaded {
            LockView()
        } else if let loadError = store.loadError {
            ContentUnavailableView {
                Label("Не удалось открыть хранилище", systemImage: "lock.trianglebadge.exclamationmark")
            } description: {
                Text(loadError)
            }
            .frame(minWidth: WindowLayout.minWidth, minHeight: WindowLayout.minHeight)
        } else {
            NavigationSplitView {
                ProfileSidebar(selection: $selection)
            } detail: {
                if let selection, let profile = store.profile(withID: selection) {
                    AccountGrid(profile: profile, searchText: searchText)
                        .navigationSplitViewColumnWidth(min: WindowLayout.detailMinWidth, ideal: 660)
                } else {
                    ContentUnavailableView("Выберите профиль", systemImage: "person.crop.circle")
                }
            }
            .frame(minWidth: WindowLayout.minWidth, minHeight: WindowLayout.minHeight)
            .searchable(text: $searchText, prompt: "Поиск")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Добавить аккаунт", systemImage: "plus") { isAddingAccount = true }
                        .disabled(selection == nil)
                }
            }
            .focusedSceneValue(\.addAccountAction, selection == nil ? nil : { isAddingAccount = true })
            .sheet(isPresented: $isAddingAccount) {
                if let selection {
                    AddAccountView(profileID: selection)
                }
            }
            .alert("Не удалось сохранить", isPresented: saveErrorPresented) {
                Button("OK") {}
            } message: {
                Text(store.saveError ?? "")
            }
            .onAppear {
                if selection == nil { selection = store.profiles.first?.id }
            }
            .onChange(of: store.profiles.map(\.id)) { _, ids in
                if let selection, ids.contains(selection) { return }
                selection = ids.first
            }
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { store.saveError != nil },
            set: { if !$0 { store.saveError = nil } }
        )
    }
}
