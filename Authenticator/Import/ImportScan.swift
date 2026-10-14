import Foundation

/// Результат разбора всего, что пришло в зону импорта.
struct ImportScan {
    var accounts: [OTPAccount] = []
    var batches: [GoogleMigration.Batch] = []
    var foundQRCodes = 0
    var unrecognized = 0
    var unreadableFiles = 0

    var isMigration: Bool { !batches.isEmpty }

    static func scan(_ items: [ImportItem]) async -> ImportScan {
        var result = ImportScan()
        for item in items {
            switch item {
            case .image(let data):
                let payloads = (try? await QRCodeScanner.payloads(in: data)) ?? []
                result.foundQRCodes += payloads.count
                payloads.forEach { result.add(payload: $0) }
            case .text(let text):
                result.add(payload: text)
            case .unreadable:
                result.unreadableFiles += 1
            }
        }
        return result
    }

    mutating func add(payload: String) {
        if GoogleMigration.isMigrationLink(payload), let batch = try? GoogleMigration.decode(payload) {
            batches.append(batch)
            accounts += batch.accounts
        } else if let account = try? OTPAuthURI.parse(payload) {
            accounts.append(account)
        } else {
            unrecognized += 1
        }
    }

    /// Понятное объяснение, если ни одного аккаунта не нашлось.
    var failureMessage: String {
        if unreadableFiles > 0 && foundQRCodes == 0 {
            return String(localized: "Не удалось открыть файл. Попробуйте перетащить его или выбрать через обзор.")
        }
        if foundQRCodes == 0 && unrecognized == 0 {
            return String(localized: "QR-код на изображении не найден.")
        }
        return String(localized: "Это не QR-код аутентификатора.")
    }
}
