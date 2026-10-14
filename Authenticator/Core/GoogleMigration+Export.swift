import Foundation

extension GoogleMigration {
    /// Почему аккаунт нельзя перенести в Google Authenticator без искажения кодов.
    enum Incompatibility {
        /// Google Authenticator работает только с SHA-1.
        case algorithm
        /// Google Authenticator показывает только 6 цифр.
        case digits
        /// В формате переноса нет поля для периода — всегда 30 секунд.
        case period
    }

    /// Google Authenticator сам кладёт в один QR-код не больше 10 аккаунтов,
    /// чтобы код оставался достаточно крупным для камеры.
    static let accountsPerCode = 10

    static func incompatibility(of account: OTPAccount) -> Incompatibility? {
        if account.algorithm != .sha1 { return .algorithm }
        if account.digits != 6 { return .digits }
        if account.kind == .totp && account.period != 30 { return .period }
        return nil
    }

    /// Ссылки `otpauth-migration://` — по одной на QR-код, все с общим `batchID`,
    /// чтобы Google Authenticator понял, что это части одного переноса.
    static func encode(_ accounts: [OTPAccount], batchID: Int32 = .random(in: 1...Int32.max)) -> [(accounts: [OTPAccount], link: String)] {
        let batches = stride(from: 0, to: accounts.count, by: accountsPerCode).map {
            Array(accounts[$0..<min($0 + accountsPerCode, accounts.count)])
        }
        return batches.enumerated().map { index, batch in
            var payload = ProtobufWriter()
            for account in batch {
                payload.writeBytes(field: 1, parameters(for: account))
            }
            payload.writeVarint(field: 2, 1)
            payload.writeVarint(field: 3, UInt64(batches.count))
            payload.writeVarint(field: 4, UInt64(index))
            payload.writeVarint(field: 5, UInt64(batchID))
            // Как и сам Google Authenticator, кодируем «+», «/» и «=» в base64.
            let data = payload.data.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            return (batch, "otpauth-migration://offline?data=" + data)
        }
    }

    private static func parameters(for account: OTPAccount) -> Data {
        var parameters = ProtobufWriter()
        parameters.writeBytes(field: 1, account.secret)
        parameters.writeString(field: 2, account.name)
        parameters.writeString(field: 3, account.issuer)
        parameters.writeVarint(field: 4, 1) // SHA-1
        parameters.writeVarint(field: 5, 1) // 6 цифр
        switch account.kind {
        case .totp:
            parameters.writeVarint(field: 6, 2)
        case .hotp:
            parameters.writeVarint(field: 6, 1)
            parameters.writeVarint(field: 7, account.counter)
        }
        return parameters.data
    }
}
