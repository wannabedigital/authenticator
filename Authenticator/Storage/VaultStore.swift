import Foundation
import Observation

/// Состояние приложения. Каждое изменение сразу шифруется и сохраняется на диск;
/// если сохранить не удалось, изменение не применяется.
@MainActor
@Observable
final class VaultStore {
    private(set) var vault = Vault()
    /// Если хранилище не удалось прочитать, любые изменения блокируются,
    /// чтобы не перезаписать существующий файл пустым.
    private(set) var loadError: String?
    var saveError: String?

    @ObservationIgnored private let storage: VaultStorage

    init(storage: VaultStorage = .standard()) {
        self.storage = storage
        do {
            vault = try storage.load() ?? Vault(profiles: [Profile(name: "Личный")])
        } catch {
            loadError = error.localizedDescription
        }
    }

    var profiles: [Profile] { vault.profiles }

    func profile(withID id: Profile.ID) -> Profile? {
        vault.profiles.first { $0.id == id }
    }

    // MARK: Профили

    @discardableResult
    func addProfile(named name: String) -> Profile.ID {
        let profile = Profile(name: name)
        mutate { $0.profiles.append(profile) }
        return profile.id
    }

    func renameProfile(_ id: Profile.ID, to name: String) {
        mutateProfile(id) { $0.name = name }
    }

    func deleteProfile(_ id: Profile.ID) {
        mutate { $0.profiles.removeAll { $0.id == id } }
    }

    // MARK: Аккаунты

    func addAccount(_ account: OTPAccount, to profileID: Profile.ID) {
        addAccounts([account], to: profileID)
    }

    func addAccounts(_ accounts: [OTPAccount], to profileID: Profile.ID) {
        mutateProfile(profileID) { $0.accounts += accounts }
    }

    func renameAccount(_ accountID: OTPAccount.ID, in profileID: Profile.ID, issuer: String, name: String) {
        mutateAccount(accountID, in: profileID) {
            $0.issuer = issuer
            $0.name = name
        }
    }

    func incrementCounter(of accountID: OTPAccount.ID, in profileID: Profile.ID) {
        mutateAccount(accountID, in: profileID) { $0.counter += 1 }
    }

    func deleteAccount(_ accountID: OTPAccount.ID, from profileID: Profile.ID) {
        mutateProfile(profileID) { $0.accounts.removeAll { $0.id == accountID } }
    }

    func moveAccount(_ accountID: OTPAccount.ID, from sourceID: Profile.ID, to destinationID: Profile.ID) {
        mutate { vault in
            guard sourceID != destinationID,
                  let source = vault.profiles.firstIndex(where: { $0.id == sourceID }),
                  let destination = vault.profiles.firstIndex(where: { $0.id == destinationID }),
                  let index = vault.profiles[source].accounts.firstIndex(where: { $0.id == accountID })
            else { return }
            let account = vault.profiles[source].accounts.remove(at: index)
            vault.profiles[destination].accounts.append(account)
        }
    }

    // MARK: Сохранение

    private func mutateAccount(_ accountID: OTPAccount.ID, in profileID: Profile.ID, _ change: (inout OTPAccount) -> Void) {
        mutateProfile(profileID) { profile in
            guard let index = profile.accounts.firstIndex(where: { $0.id == accountID }) else { return }
            change(&profile.accounts[index])
        }
    }

    private func mutateProfile(_ id: Profile.ID, _ change: (inout Profile) -> Void) {
        mutate { vault in
            guard let index = vault.profiles.firstIndex(where: { $0.id == id }) else { return }
            change(&vault.profiles[index])
        }
    }

    private func mutate(_ change: (inout Vault) -> Void) {
        guard loadError == nil else { return }
        var updated = vault
        change(&updated)
        do {
            try storage.save(updated)
            vault = updated
        } catch {
            saveError = error.localizedDescription
        }
    }
}
