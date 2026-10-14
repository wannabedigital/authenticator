import SwiftUI

struct ContentView: View {
    @Environment(VaultStore.self) private var store
    @Environment(AppLock.self) private var lock
    @State private var selection: Profile.ID?
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var accountSearch = SearchState()
    @State private var profileSearch = SearchState()
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
            NavigationSplitView(columnVisibility: $columnVisibility) {
                ProfileSidebar(selection: $selection, search: $profileSearch)
            } detail: {
                Group {
                    if let selection, let profile = store.profile(withID: selection) {
                        AccountGrid(profile: profile, searchText: accountSearch.query)
                    } else {
                        ContentUnavailableView("Выберите профиль", systemImage: "person.crop.circle")
                    }
                }
                .safeAreaBar(edge: .top) {
                    if accountSearch.isPresented {
                        SearchField(text: $accountSearch.query, prompt: String(localized: "Поиск кодов"), focusRequest: accountSearch.focusRequest) {
                            withAnimation(SearchState.animation) { accountSearch.dismiss() }
                        }
                        .padding(.horizontal, WindowLayout.gridPadding)
                        .padding(.vertical, 8)
                        .transition(.opacity)
                    }
                }
                .navigationSplitViewColumnWidth(min: WindowLayout.detailMinWidth, ideal: 660)
            }
            .frame(minWidth: WindowLayout.minWidth, minHeight: WindowLayout.minHeight)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Добавить аккаунт", systemImage: "plus") { isAddingAccount = true }
                        .disabled(selection == nil)
                }
            }
            .focusedSceneValue(\.addAccountAction, selection == nil ? nil : { isAddingAccount = true })
            .focusedSceneValue(\.findAccountAction, selection == nil ? nil : {
                withAnimation(SearchState.animation) { accountSearch.present() }
            })
            .focusedSceneValue(\.findProfileAction) {
                // Поле поиска живёт в боковой панели — если она скрыта, сначала показываем её.
                withAnimation(SearchState.animation) {
                    columnVisibility = .all
                    profileSearch.present()
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
