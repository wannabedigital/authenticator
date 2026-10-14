import Foundation

struct Profile: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    /// Имя символа SF Symbols.
    var symbol = "person.fill"
    var color = ProfileColor.blue
    var accounts: [OTPAccount] = []
}

extension Profile {
    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, color, accounts
    }

    /// Хранилища, созданные до появления значков, не содержат `symbol` и `color`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? "person.fill"
        color = (try? container.decodeIfPresent(ProfileColor.self, forKey: .color)) ?? .blue
        accounts = try container.decode([OTPAccount].self, forKey: .accounts)
    }
}

enum ProfileColor: String, Codable, CaseIterable, Sendable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, gray
}

/// Всё содержимое хранилища. На диске лежит только в зашифрованном виде.
struct Vault: Codable, Sendable {
    var version = 1
    var profiles: [Profile] = []
}
