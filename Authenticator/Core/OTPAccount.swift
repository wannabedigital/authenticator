import CryptoKit
import Foundation

enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

enum OTPKind: String, Codable, CaseIterable, Sendable {
    /// Код меняется по времени (RFC 6238) — так работает почти каждый сервис.
    case totp
    /// Код меняется по счётчику (RFC 4226) — встречается редко.
    case hotp
}

struct OTPAccount: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var issuer: String
    var name: String
    var secret: Data
    var kind: OTPKind = .totp
    var algorithm: OTPAlgorithm = .sha1
    var digits = 6
    var period = 30
    var counter: UInt64 = 0
}

extension OTPAccount {
    var title: String { issuer.isEmpty ? name : issuer }
    var subtitle: String? { issuer.isEmpty || name.isEmpty ? nil : name }

    func code(at date: Date) -> String {
        let movingFactor = switch kind {
        case .totp: UInt64(max(0, date.timeIntervalSince1970) / Double(max(period, 1)))
        case .hotp: counter
        }
        return OTPGenerator.code(secret: secret, counter: movingFactor, algorithm: algorithm, digits: digits)
    }

    /// Сколько секунд осталось до смены TOTP-кода.
    func secondsRemaining(at date: Date) -> TimeInterval {
        let period = Double(max(self.period, 1))
        return period - date.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
    }
}

enum OTPGenerator {
    /// HOTP по RFC 4226; TOTP — это HOTP, где счётчик равен номеру временного интервала.
    static func code(secret: Data, counter: UInt64, algorithm: OTPAlgorithm, digits: Int) -> String {
        let message = withUnsafeBytes(of: counter.bigEndian) { Data($0) }
        let key = SymmetricKey(data: secret)
        let hash: [UInt8] = switch algorithm {
        case .sha1: Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }

        // Динамическое усечение, RFC 4226 §5.3.
        let offset = Int(hash[hash.count - 1] & 0x0F)
        var binary = UInt32(hash[offset] & 0x7F) << 24
        binary |= UInt32(hash[offset + 1]) << 16
        binary |= UInt32(hash[offset + 2]) << 8
        binary |= UInt32(hash[offset + 3])

        let digits = min(max(digits, 1), 9)
        let modulus = (0..<digits).reduce(UInt32(1)) { result, _ in result * 10 }
        let value = String(binary % modulus)
        return String(repeating: "0", count: digits - value.count) + value
    }

    /// «123456» → «123 456», «12345678» → «1234 5678».
    static func grouped(_ code: String) -> String {
        guard code.count > 4 else { return code }
        let middle = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<middle]) \(code[middle...])"
    }
}
