import SwiftUI

struct ContentView: View {
    @Environment(VaultStore.self) private var store
    @State private var selection: Profile.ID?
    @State private var searchText = ""
    @State private var isAddingAccount = false

    var body: some View {
        if let loadError = store.loadError {
            ContentUnavailableView {
                Label("Не удалось открыть хранилище", systemImage: "lock.trianglebadge.exclamationmark")
            } description: {
                Text(loadError)
            }
            .frame(minWidth: 480, minHeight: 320)
        } else {
            NavigationSplitView {
                ProfileSidebar(selection: $selection)
            } detail: {
                if let selection, let profile = store.profile(withID: selection) {
                    AccountGrid(profile: profile, searchText: searchText)
                } else {
                    ContentUnavailableView("Выберите профиль", systemImage: "person.crop.circle")
                }
            }
            .frame(minWidth: 640, minHeight: 400)
            .searchable(text: $searchText, prompt: "Поиск")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Добавить аккаунт", systemImage: "plus") { isAddingAccount = true }
                        .disabled(selection == nil)
                        .keyboardShortcut("n")
                }
            }
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
