import CommonCrypto
import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// Зашифрованная резервная копия для переноса между копиями Authenticator.
///
/// Файл — JSON-обёртка: параметры PBKDF2 и шифротекст AES-256-GCM. Ключ выводится из пароля,
/// а параметры заголовка участвуют в проверке подлинности (associated data),
/// поэтому их нельзя незаметно подменить.
enum BackupFile {
    static let contentType = UTType(exportedAs: "com.wannabevirtual.authenticator.backup")
    /// Рекомендация OWASP для PBKDF2-HMAC-SHA256.
    static let iterations = 600_000

    private static let format = "authenticator-backup"
    private static let algorithm = "PBKDF2-HMAC-SHA256"

    enum Failure: LocalizedError {
        case notBackup
        case unsupportedVersion
        case wrongPassword
        case keyDerivationFailed

        var errorDescription: String? {
            switch self {
            case .notBackup: String(localized: "Это не файл резервной копии Authenticator")
            case .unsupportedVersion: String(localized: "Файл создан более новой версией Authenticator")
            case .wrongPassword: String(localized: "Неверный пароль или файл повреждён")
            case .keyDerivationFailed: String(localized: "Не удалось получить ключ из пароля")
            }
        }
    }

    private struct Envelope: Codable {
        var format: String
        var version: Int
        var kdf: KeyDerivation
        var ciphertext: Data
    }

    private struct KeyDerivation: Codable {
        var algorithm: String
        var iterations: Int
        var salt: Data
    }

    private struct Payload: Codable {
        var version = 1
        var exportedAt: Date
        var profiles: [Profile]
    }

    static func seal(_ profiles: [Profile], password: String) throws -> Data {
        let kdf = KeyDerivation(algorithm: algorithm, iterations: iterations, salt: randomBytes(16))
        let key = try deriveKey(password: password, salt: kdf.salt, iterations: kdf.iterations)
        let plaintext = try JSONEncoder().encode(Payload(exportedAt: .now, profiles: profiles))
        // `combined` пуст только при нестандартной длине nonce, здесь она стандартная.
        let ciphertext = try AES.GCM.seal(plaintext, using: key, authenticating: associatedData(version: 1, kdf: kdf)).combined!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Envelope(format: format, version: 1, kdf: kdf, ciphertext: ciphertext))
    }

    static func open(_ data: Data, password: String) throws -> [Profile] {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data), envelope.format == format else {
            throw Failure.notBackup
        }
        guard envelope.version == 1, envelope.kdf.algorithm == algorithm else { throw Failure.unsupportedVersion }
        // Защита от файла, который заставил бы считать ключ часами.
        guard (1...10_000_000).contains(envelope.kdf.iterations) else { throw Failure.notBackup }

        let key = try deriveKey(password: password, salt: envelope.kdf.salt, iterations: envelope.kdf.iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.ciphertext)
            let plaintext = try AES.GCM.open(box, using: key, authenticating: associatedData(version: envelope.version, kdf: envelope.kdf))
            return try JSONDecoder().decode(Payload.self, from: plaintext).profiles
        } catch {
            throw Failure.wrongPassword
        }
    }

    static func isBackup(_ data: Data) -> Bool {
        (try? JSONDecoder().decode(Envelope.self, from: data))?.format == format
    }

    /// PBKDF2-HMAC-SHA256 из системного CommonCrypto. Пароль нормализуется (NFC),
    /// чтобы «й», набранная по-разному на разных клавиатурах, давала один ключ.
    static func deriveKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let password = password.precomposedStringWithCanonicalMapping
        let salt = [UInt8](salt)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password, password.utf8.count,
            salt, salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(iterations),
            &derived, derived.count
        )
        guard status == kCCSuccess else { throw Failure.keyDerivationFailed }
        return SymmetricKey(data: derived)
    }

    private static func associatedData(version: Int, kdf: KeyDerivation) -> Data {
        Data("\(format)|\(version)|\(kdf.algorithm)|\(kdf.iterations)|\(kdf.salt.base64EncodedString())".utf8)
    }

    private static func randomBytes(_ count: Int) -> Data {
        SymmetricKey(size: SymmetricKeySize(bitCount: count * 8)).withUnsafeBytes { Data($0) }
    }
}
