import CryptoKit
import Foundation

/// Читает и пишет хранилище: JSON, зашифрованный AES-256-GCM.
/// Файл лежит в контейнере песочницы (~/Library/Containers/<bundle id>/…),
/// ключ — в связке ключей. Без ключа файл бесполезен.
struct VaultStorage: Sendable {
    let fileURL: URL
    let keyStore: KeychainKeyStore

    enum Failure: LocalizedError {
        case missingKey
        var errorDescription: String? {
            String(localized: "Файл хранилища найден, но ключ шифрования в связке ключей отсутствует. Файл не был изменён.")
        }
    }

    static func standard() -> VaultStorage {
        let directory = URL.applicationSupportDirectory.appending(path: "Authenticator", directoryHint: .isDirectory)
        return VaultStorage(
            fileURL: directory.appending(path: "vault.sealed"),
            keyStore: KeychainKeyStore(service: Bundle.main.bundleIdentifier ?? "Authenticator")
        )
    }

    /// `nil` — хранилища ещё нет (первый запуск).
    func load() throws -> Vault? {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return nil }
        guard let key = try keyStore.readKey() else { throw Failure.missingKey }
        let box = try AES.GCM.SealedBox(combined: Data(contentsOf: fileURL))
        let plaintext = try AES.GCM.open(box, using: key)
        return try JSONDecoder().decode(Vault.self, from: plaintext)
    }

    func save(_ vault: Vault) throws {
        let key = try keyStore.readKey() ?? keyStore.createKey()
        let plaintext = try JSONEncoder().encode(vault)
        // `combined` пуст только при нестандартной длине nonce, здесь она стандартная.
        let sealed = try AES.GCM.seal(plaintext, using: key).combined!
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try sealed.write(to: fileURL, options: .atomic)
    }
}
