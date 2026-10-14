import Foundation

/// Кодирование Base32 по RFC 4648 — в этом формате сервисы выдают секретные ключи.
enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    /// Декодирует строку, игнорируя регистр, пробелы, дефисы и `=` в конце.
    /// Возвращает `nil`, если встретился символ не из алфавита Base32.
    static func decode(_ string: String) -> Data? {
        let characters = string.uppercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "=" }
        guard !characters.isEmpty else { return nil }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(characters.count * 5 / 8)
        var buffer: UInt32 = 0
        var bitCount = 0

        for character in characters {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                bytes.append(UInt8(truncatingIfNeeded: buffer >> UInt32(bitCount)))
            }
        }
        return Data(bytes)
    }

    /// Кодирует байты в Base32 без `=` в конце (как принято в ссылках otpauth://).
    static func encode(_ data: Data) -> String {
        var result = ""
        var buffer: UInt32 = 0
        var bitCount = 0

        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                result.append(alphabet[Int((buffer >> UInt32(bitCount)) & 0x1F)])
            }
        }
        if bitCount > 0 {
            result.append(alphabet[Int((buffer << UInt32(5 - bitCount)) & 0x1F)])
        }
        return result
    }
}
