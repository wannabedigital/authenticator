import SwiftUI

struct AccountGrid: View {
    @Environment(VaultStore.self) private var store
    let profile: Profile
    let searchText: String

    @State private var copiedID: OTPAccount.ID?
    @State private var copyCount = 0
    @State private var accountToEdit: OTPAccount?
    @State private var accountToDelete: OTPAccount?

    private var accounts: [OTPAccount] {
        let query = searchText.trimmed
        guard !query.isEmpty else { return profile.accounts }
        return profile.accounts.filter {
            $0.issuer.localizedStandardContains(query) || $0.name.localizedStandardContains(query)
        }
    }

    var body: some View {
        Group {
            if profile.accounts.isEmpty {
                ContentUnavailableView {
                    Label("Нет аккаунтов", systemImage: "key.horizontal")
                } description: {
                    Text("Нажмите «+» в панели инструментов, чтобы добавить первый код.")
                }
            } else if accounts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    // Тикаем ровно на границе секунды, чтобы коды менялись без задержки.
                    TimelineView(.periodic(from: Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded(.down)), by: 1)) { context in
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: WindowLayout.cardMinWidth), spacing: WindowLayout.cardSpacing)], spacing: WindowLayout.cardSpacing) {
                            ForEach(accounts) { account in
                                AccountCard(
                                    account: account,
                                    date: context.date,
                                    isCopied: copiedID == account.id,
                                    onCopy: { copy(account) },
                                    onAdvanceCounter: { store.incrementCounter(of: account.id, in: profile.id) }
                                )
                                .contextMenu { menu(for: account) }
                            }
                        }
                        .padding(WindowLayout.gridPadding)
                    }
                }
            }
        }
        .navigationTitle(profile.name)
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
        .sheet(item: $accountToEdit) { account in
            EditAccountView(account: account, profileID: profile.id)
        }
        .confirmationDialog(
            "Удалить «\(accountToDelete?.title ?? "")»?",
            isPresented: Binding(get: { accountToDelete != nil }, set: { if !$0 { accountToDelete = nil } }),
            titleVisibility: .visible,
            presenting: accountToDelete
        ) { account in
            Button("Удалить", role: .destructive) { store.deleteAccount(account.id, from: profile.id) }
        } message: { _ in
            Text("Если на сервисе включена двухфакторная защита, без этого кода войти не получится. Убедитесь, что у вас есть резервные коды.")
        }
    }

    @ViewBuilder
    private func menu(for account: OTPAccount) -> some View {
        Button("Скопировать код", systemImage: "doc.on.doc") { copy(account) }
        Button("Изменить…", systemImage: "pencil") { accountToEdit = account }
        let otherProfiles = store.profiles.filter { $0.id != profile.id }
        if !otherProfiles.isEmpty {
            Menu("Переместить в профиль", systemImage: "arrow.right.circle") {
                ForEach(otherProfiles) { other in
                    Button(other.name) { store.moveAccount(account.id, from: profile.id, to: other.id) }
                }
            }
        }
        Divider()
        Button("Удалить…", systemImage: "trash", role: .destructive) { accountToDelete = account }
    }

    private func copy(_ account: OTPAccount) {
        Clipboard.copySecret(account.code(at: .now))
        copiedID = account.id
        copyCount += 1
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
