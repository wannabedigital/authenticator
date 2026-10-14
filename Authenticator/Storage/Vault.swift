import Foundation

struct Profile: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var accounts: [OTPAccount] = []
}

/// Всё содержимое хранилища. На диске лежит только в зашифрованном виде.
struct Vault: Codable, Sendable {
    var version = 1
    var profiles: [Profile] = []
}
