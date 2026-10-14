import Foundation

/// Минимальная запись Protocol Buffers — пара к `ProtobufReader` для формата переноса Google Authenticator.
struct ProtobufWriter {
    private(set) var data = Data()

    mutating func writeVarint(field: Int, _ value: UInt64) {
        appendVarint(UInt64(field) << 3)
        appendVarint(value)
    }

    mutating func writeBytes(field: Int, _ bytes: Data) {
        appendVarint(UInt64(field) << 3 | 2)
        appendVarint(UInt64(bytes.count))
        data.append(bytes)
    }

    mutating func writeString(field: Int, _ string: String) {
        writeBytes(field: field, Data(string.utf8))
    }

    private mutating func appendVarint(_ value: UInt64) {
        var value = value
        repeat {
            var byte = UInt8(value & 0x7F)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            data.append(byte)
        } while value != 0
    }
}
