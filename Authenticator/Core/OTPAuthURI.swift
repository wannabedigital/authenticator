import Foundation

/// Ссылки вида `otpauth://totp/GitHub:me@example.com?secret=…&issuer=GitHub`.
/// Именно они зашиты в QR-коды, которые показывают сайты при включении 2FA.
enum OTPAuthURI {
    enum ParseError: LocalizedError {
        case notOTPAuth
        case unsupportedType
        case missingSecret
        case invalidSecret
        case invalidParameter(String)

        var errorDescription: String? {
            switch self {
            case .notOTPAuth: "Это не ссылка otpauth://"
            case .unsupportedType: "Поддерживаются только типы totp и hotp"
            case .missingSecret: "В ссылке нет секретного ключа"
            case .invalidSecret: "Секретный ключ повреждён"
            case .invalidParameter(let name): "Недопустимое значение параметра «\(name)»"
            }
        }
    }

    static func parse(_ string: String) throws -> OTPAccount {
        guard let components = URLComponents(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "otpauth"
        else { throw ParseError.notOTPAuth }

        guard let kind = components.host.flatMap({ OTPKind(rawValue: $0.lowercased()) }) else {
            throw ParseError.unsupportedType
        }

        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name.lowercased() == name }?.value
        }

        guard let secretString = value("secret"), !secretString.isEmpty else { throw ParseError.missingSecret }
        guard let secret = Base32.decode(secretString), !secret.isEmpty else { throw ParseError.invalidSecret }

        // Метка: «Issuer:account» или просто «account».
        var label = components.path
        if label.hasPrefix("/") { label.removeFirst() }
        var issuer = ""
        var name = label
        if let colon = label.firstIndex(of: ":") {
            issuer = label[..<colon].trimmingCharacters(in: .whitespaces)
            name = label[label.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        if let explicitIssuer = value("issuer"), !explicitIssuer.isEmpty {
            issuer = explicitIssuer
        }

        var account = OTPAccount(issuer: issuer, name: name, secret: secret, kind: kind)

        if let algorithm = value("algorithm") {
            guard let parsed = OTPAlgorithm(rawValue: algorithm.uppercased()) else {
                throw ParseError.invalidParameter("algorithm")
            }
            account.algorithm = parsed
        }
        if let digits = value("digits") {
            guard let parsed = Int(digits), (6...8).contains(parsed) else {
                throw ParseError.invalidParameter("digits")
            }
            account.digits = parsed
        }
        if let period = value("period") {
            guard let parsed = Int(period), parsed > 0 else {
                throw ParseError.invalidParameter("period")
            }
            account.period = parsed
        }
        if let counter = value("counter") {
            guard let parsed = UInt64(counter) else {
                throw ParseError.invalidParameter("counter")
            }
            account.counter = parsed
        }
        return account
    }

    static func string(for account: OTPAccount) -> String {
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = account.kind.rawValue
        components.path = "/" + (account.issuer.isEmpty ? account.name : "\(account.issuer):\(account.name)")

        var items = [URLQueryItem(name: "secret", value: Base32.encode(account.secret))]
        if !account.issuer.isEmpty {
            items.append(URLQueryItem(name: "issuer", value: account.issuer))
        }
        items.append(URLQueryItem(name: "algorithm", value: account.algorithm.rawValue))
        items.append(URLQueryItem(name: "digits", value: String(account.digits)))
        switch account.kind {
        case .totp: items.append(URLQueryItem(name: "period", value: String(account.period)))
        case .hotp: items.append(URLQueryItem(name: "counter", value: String(account.counter)))
        }
        components.queryItems = items
        return components.string ?? ""
    }
}
