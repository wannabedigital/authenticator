import Foundation

/// Формат «Перенос аккаунтов» из Google Authenticator:
/// `otpauth-migration://offline?data=<base64 protobuf>`.
///
/// Схема сообщения (MigrationPayload):
///   1 otp_parameters (repeated) — secret = 1, name = 2, issuer = 3,
///     algorithm = 4, digits = 5, type = 6, counter = 7
///   2 version, 3 batch_size, 4 batch_index, 5 batch_id
///
/// Если аккаунтов много, Google Authenticator делит их на несколько QR-кодов —
/// каждый из них является отдельной «партией» (batch).
enum GoogleMigration {
    struct Batch {
        var accounts: [OTPAccount] = []
        var index = 0
        var size = 1
        var id = 0
    }

    enum Failure: LocalizedError {
        case notMigrationLink
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .notMigrationLink: String(localized: "Это не ссылка переноса Google Authenticator")
            case .invalidPayload: String(localized: "Данные переноса повреждены")
            }
        }
    }

    static func isMigrationLink(_ string: String) -> Bool {
        string.trimmed.lowercased().hasPrefix("otpauth-migration:")
    }

    static func decode(_ link: String) throws -> Batch {
        guard let components = URLComponents(string: link.trimmed),
              components.scheme?.lowercased() == "otpauth-migration",
              let encoded = components.queryItems?.first(where: { $0.name == "data" })?.value
        else { throw Failure.notMigrationLink }

        guard let data = Data(base64Encoded: normalizedBase64(encoded)) else { throw Failure.invalidPayload }
        do {
            return try decodePayload(data)
        } catch {
            throw Failure.invalidPayload
        }
    }

    static func decodePayload(_ data: Data) throws -> Batch {
        var batch = Batch()
        var reader = ProtobufReader(data)
        while let field = try reader.nextField() {
            switch (field.number, field.value) {
            case (1, .bytes(let parameters)):
                if let account = try decodeParameters(parameters) {
                    batch.accounts.append(account)
                }
            case (3, .varint(let value)): batch.size = max(1, Int(Int32(truncatingIfNeeded: value)))
            case (4, .varint(let value)): batch.index = max(0, Int(Int32(truncatingIfNeeded: value)))
            case (5, .varint(let value)): batch.id = Int(Int32(truncatingIfNeeded: value))
            default: break
            }
        }
        return batch
    }

    /// `nil` — аккаунт без ключа или с алгоритмом MD5, который не поддерживается.
    private static func decodeParameters(_ data: Data) throws -> OTPAccount? {
        var account = OTPAccount(issuer: "", name: "", secret: Data())
        var reader = ProtobufReader(data)
        while let field = try reader.nextField() {
            switch (field.number, field.value) {
            case (1, .bytes(let secret)):
                account.secret = secret
            case (2, .bytes(let name)):
                account.name = String(decoding: name, as: UTF8.self)
            case (3, .bytes(let issuer)):
                account.issuer = String(decoding: issuer, as: UTF8.self)
            case (4, .varint(let algorithm)):
                switch algorithm {
                case 0, 1: account.algorithm = .sha1
                case 2: account.algorithm = .sha256
                case 3: account.algorithm = .sha512
                default: return nil
                }
            case (5, .varint(let digits)):
                account.digits = digits == 2 ? 8 : 6
            case (6, .varint(let type)):
                account.kind = type == 1 ? .hotp : .totp
            case (7, .varint(let counter)):
                account.counter = counter
            default:
                break
            }
        }
        guard !account.secret.isEmpty else { return nil }

        // Google Authenticator часто хранит имя как «Issuer:account».
        if let colon = account.name.firstIndex(of: ":") {
            let prefix = String(account.name[..<colon]).trimmed
            if account.issuer.isEmpty || prefix == account.issuer {
                account.issuer = account.issuer.isEmpty ? prefix : account.issuer
                account.name = String(account.name[account.name.index(after: colon)...]).trimmed
            }
        }
        return account
    }

    /// Принимает и обычный base64, и URL-safe вариант, с `=` в конце и без.
    private static func normalizedBase64(_ string: String) -> String {
        var result = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: " ", with: "+")
        let remainder = result.count % 4
        if remainder > 0 {
            result += String(repeating: "=", count: 4 - remainder)
        }
        return result
    }
}
