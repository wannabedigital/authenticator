import SwiftUI

struct ContentView: View {
    @Environment(VaultStore.self) private var store
    @Environment(AppLock.self) private var lock
    @State private var selection: Profile.ID?
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var accountSearch = SearchState()
    @State private var profileSearch = SearchState()
    @State private var isAddingAccount = false
    @State private var isExporting = false
    @State private var isPickingBackup = false
    @State private var backupToOpen: PendingBackup?
    @State private var backupError: String?

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
                detail
            }
            .frame(minWidth: WindowLayout.minWidth, minHeight: WindowLayout.minHeight)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Добавить аккаунт", systemImage: "plus") { isAddingAccount = true }
                        .disabled(selection == nil)
                }
            }
            .focusedSceneValue(\.addAccountAction, selection == nil ? nil : { isAddingAccount = true })
            .focusedSceneValue(\.findProfileAction) {
                // Поле поиска живёт в боковой панели — если она скрыта, сначала показываем её.
                withAnimation(SearchState.animation) {
                    columnVisibility = .all
                    profileSearch.present()
                }
            }
            .focusedSceneValue(\.exportAction, store.profiles.allSatisfy(\.accounts.isEmpty) ? nil : { isExporting = true })
            .sheet(isPresented: $isExporting) {
                ExportView()
            }
            .focusedSceneValue(\.openBackupAction) { isPickingBackup = true }
            .fileImporter(isPresented: $isPickingBackup, allowedContentTypes: [BackupFile.contentType]) { result in
                guard case .success(let url) = result else { return }
                let isScoped = url.startAccessingSecurityScopedResource()
                defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), BackupFile.isBackup(data) {
                    backupToOpen = PendingBackup(data: data)
                } else {
                    backupError = String(localized: "Это не файл резервной копии Authenticator")
                }
            }
            .sheet(item: $backupToOpen) { backup in
                BackupImportView(data: backup.data)
            }
            .alert("Не удалось открыть файл", isPresented: Binding(get: { backupError != nil }, set: { if !$0 { backupError = nil } })) {
                Button("OK") {}
            } message: {
                Text(backupError ?? "")
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
            .onChange(of: lock.isClosingSheets) { _, closing in
                guard closing else { return }
                isAddingAccount = false
                isExporting = false
                isPickingBackup = false
                backupToOpen = nil
                backupError = nil
                store.saveError = nil
            }
            .onChange(of: store.profiles.map(\.id)) { _, ids in
                if let selection, ids.contains(selection) { return }
                selection = ids.first
            }
        }
    }

    private var detail: some View {
        // Обычная колонка, а не safeAreaBar: на macOS панель получает жёсткий край
        // с разделителями над полем и под ним, а так поле лежит прямо на фоне окна.
        VStack(spacing: 0) {
            if accountSearch.isPresented {
                AccountSearchBar(
                    search: $accountSearch,
                    selectedProfile: selectedProfile,
                    showsScope: store.profiles.count > 1
                )
                .padding(.horizontal, WindowLayout.gridPadding)
                .padding(.vertical, 8)
                .transition(.opacity)
            }
            Group {
                if accountSearch.isGlobal {
                    AccountGrid(profiles: store.profiles, searchText: accountSearch.query, groupsByProfile: true)
                        .navigationTitle("Все профили")
                } else if let selectedProfile {
                    AccountGrid(profiles: [selectedProfile], searchText: accountSearch.query)
                        .navigationTitle(selectedProfile.name)
                } else {
                    ContentUnavailableView("Выберите профиль", systemImage: "person.crop.circle")
                }
            }
            // Пустое состояние занимает ровно свой размер, и без растягивания
            // колонка центрирует его вместе с полем — поле уезжает в середину окна.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewColumnWidth(min: WindowLayout.detailMinWidth, ideal: 660)
        .focusedSceneValue(\.findAccountAction, selection == nil ? nil : {
            withAnimation(SearchState.animation) { accountSearch.present() }
        })
        .focusedSceneValue(\.findInAllProfilesAction, store.profiles.isEmpty ? nil : {
            withAnimation(SearchState.animation) { accountSearch.present(scope: .allProfiles) }
        })
        .onChange(of: selection) {
            // Выбранный в боковой панели профиль становится областью поиска. Пустой поиск при этом
            // закрывается, как и обычный, а с запросом остаётся — и показывает, что нашлось в профиле.
            if accountSearch.isGlobal { accountSearch.scope = .selectedProfile }
        }
    }

    private var selectedProfile: Profile? {
        selection.flatMap(store.profile(withID:))
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { store.saveError != nil },
            set: { if !$0 { store.saveError = nil } }
        )
    }
}

/// Поле поиска кодов и под ним — где искать: в выбранном профиле или во всех.
private struct AccountSearchBar: View {
    @Binding var search: SearchState
    let selectedProfile: Profile?
    let showsScope: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Во всех профилях пустой запрос показывает все коды — поиск остаётся открытым.
            SearchField(
                text: $search.query, prompt: String(localized: "Поиск кодов"),
                focusRequest: search.focusRequest, closesWhenEmpty: !search.isGlobal
            ) {
                withAnimation(SearchState.animation) { search.dismiss() }
            }
            if let selectedProfile, showsScope {
                Picker("Искать в", selection: $search.scope) {
                    Text("Все профили").tag(SearchState.Scope.allProfiles)
                    Text(selectedProfile.name).tag(SearchState.Scope.selectedProfile)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }
}

/// Прочитанный файл резервной копии, который ждёт пароля.
private struct PendingBackup: Identifiable {
    let id = UUID()
    let data: Data
}
