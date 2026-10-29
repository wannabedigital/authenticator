import SwiftUI

struct AccountGrid: View {
    @Environment(VaultStore.self) private var store
    @Environment(AppLock.self) private var lock
    /// Профили, чьи аккаунты показывает сетка.
    let profiles: [Profile]
    let searchText: String
    /// Аккаунты идут группами под названиями профилей — когда видно сразу несколько профилей.
    var groupsByProfile = false

    @State private var copiedID: OTPAccount.ID?
    @State private var copyCount = 0
    @State private var accountToEdit: ProfileAccount?
    @State private var accountToDelete: ProfileAccount?
    @State private var accountForQRCode: OTPAccount?
    @State private var isWindowVisible = true

    /// Профили с подходящими под запрос аккаунтами; профили без них пропускаем.
    private var sections: [Profile] {
        let query = searchText.trimmed
        return profiles.compactMap { profile in
            var profile = profile
            if !query.isEmpty {
                profile.accounts = profile.accounts.filter {
                    $0.issuer.localizedStandardContains(query) || $0.name.localizedStandardContains(query)
                }
            }
            return profile.accounts.isEmpty ? nil : profile
        }
    }

    var body: some View {
        let sections = sections
        Group {
            if profiles.allSatisfy(\.accounts.isEmpty) {
                ContentUnavailableView {
                    Label("Нет аккаунтов", systemImage: "key.horizontal")
                } description: {
                    Text("Нажмите «+» в панели инструментов, чтобы добавить первый код.")
                }
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: WindowLayout.cardMinWidth), spacing: WindowLayout.cardSpacing)], spacing: WindowLayout.cardSpacing) {
                        ForEach(sections) { profile in
                            if groupsByProfile {
                                Section {
                                    cards(of: profile)
                                } header: {
                                    ProfileHeader(profile: profile)
                                        .padding(.top, profile.id == sections.first?.id ? 0 : 8)
                                }
                            } else {
                                cards(of: profile)
                            }
                        }
                    }
                    .padding(WindowLayout.gridPadding)
                }
                .background(WindowVisibilityReader(isVisible: $isWindowVisible))
            }
        }
        .onChange(of: lock.isClosingSheets) { _, closing in
            guard closing else { return }
            accountToEdit = nil
            accountForQRCode = nil
            accountToDelete = nil
        }
        .overlay(alignment: .bottom) {
            if copiedID != nil {
                CopiedToast()
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: copiedID)
        .task(id: copyCount) {
            guard copiedID != nil else { return }
            do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
            copiedID = nil
        }
        .sheet(item: $accountForQRCode) { account in
            AccountQRView(account: account)
        }
        .sheet(item: $accountToEdit) { item in
            EditAccountView(account: item.account, profileID: item.profileID)
        }
        .confirmationDialog(
            "Удалить «\(accountToDelete?.account.title ?? "")»?",
            isPresented: Binding(get: { accountToDelete != nil }, set: { if !$0 { accountToDelete = nil } }),
            titleVisibility: .visible,
            presenting: accountToDelete
        ) { item in
            Button("Удалить", role: .destructive) { store.deleteAccount(item.account.id, from: item.profileID) }
        } message: { _ in
            Text("Если на сервисе включена двухфакторная защита, без этого кода войти не получится. Убедитесь, что у вас есть резервные коды.")
        }
    }

    private func cards(of profile: Profile) -> some View {
        ForEach(profile.accounts.map { ProfileAccount(account: $0, profileID: profile.id) }) { item in
            let account = item.account
            // Таймер у каждой карточки свой, а контекстное меню — снаружи него: под общим таймером сетки
            // меню пересобиралось каждую секунду, и открытое подменю «Переместить в профиль» мигало.
            // Расписание у всех карточек одно, так что коды по-прежнему меняются разом.
            TimelineView(EverySecond(isPaused: !isWindowVisible)) { context in
                AccountCard(
                    account: account,
                    date: context.date,
                    isCopied: copiedID == account.id,
                    onCopy: { copy(account) },
                    onAdvanceCounter: { store.incrementCounter(of: account.id, in: profile.id) }
                )
            }
            .contextMenu { menu(for: account, in: profile.id) }
        }
    }

    @ViewBuilder
    private func menu(for account: OTPAccount, in profileID: Profile.ID) -> some View {
        let item = ProfileAccount(account: account, profileID: profileID)
        Button("Скопировать код", systemImage: "doc.on.doc") { copy(account) }
        Button("Изменить…", systemImage: "pencil") { accountToEdit = item }
        Button("Показать QR-код…", systemImage: "qrcode") { showQRCode(for: account) }
        let otherProfiles = store.profiles.filter { $0.id != profileID }
        if !otherProfiles.isEmpty {
            Menu("Переместить в профиль", systemImage: "arrow.right.circle") {
                ForEach(otherProfiles) { other in
                    Button(other.name) { store.moveAccount(account.id, from: profileID, to: other.id) }
                }
            }
        }
        Divider()
        Button("Удалить…", systemImage: "trash", role: .destructive) { accountToDelete = item }
    }

    private func showQRCode(for account: OTPAccount) {
        Task {
            guard await lock.confirmIdentity(reason: String(localized: "показать QR-код с секретным ключом")) else { return }
            accountForQRCode = account
        }
    }

    private func copy(_ account: OTPAccount) {
        Clipboard.copySecret(account.code(at: .now))
        copiedID = account.id
        copyCount += 1
    }
}

/// Аккаунт вместе с профилем, в котором он лежит.
private struct ProfileAccount: Identifiable {
    let account: OTPAccount
    let profileID: Profile.ID

    /// Профиль входит в идентичность: перенесённый в другой профиль аккаунт сетка показывает новой карточкой.
    /// Ленивая сетка различает карточки только по этому id, и по одному id аккаунта она подставляла
    /// после переноса закешированную карточку из старого профиля — та больше не получала обновлений сетки.
    var id: [UUID] { [profileID, account.id] }
}

/// Заголовок группы карточек в поиске по всем профилям.
private struct ProfileHeader: View {
    let profile: Profile

    var body: some View {
        Label {
            Text(profile.name)
        } icon: {
            ProfileIcon(profile: profile, size: 20)
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Тикает ровно на границе каждой секунды, чтобы коды менялись без задержки.
/// Пока окна не видно, расписание стоит: в фоне карточки не тратят процессорное время.
private struct EverySecond: TimelineSchedule {
    let isPaused: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var date = Date(timeIntervalSince1970: startDate.timeIntervalSince1970.rounded(.down))
        var isFirst = true
        return AnyIterator {
            guard isFirst || !isPaused else { return nil }
            isFirst = false
            defer { date += 1 }
            return date
        }
    }
}

private struct CopiedToast: View {
    var body: some View {
        Label("Код скопирован", systemImage: "checkmark.circle.fill")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
    }
}
