import Foundation

/// Минимальный разбор Protocol Buffers — ровно столько, сколько нужно
/// для формата переноса Google Authenticator. Без сторонних библиотек.
struct ProtobufReader {
    enum Value {
        case varint(UInt64)
        case bytes(Data)
        /// Поля фиксированной длины (fixed32/fixed64) нам не нужны — пропускаем.
        case skipped
    }

    enum Failure: Error {
        case truncated
        case malformedVarint
        case unsupportedWireType(UInt64)
    }

    private let bytes: [UInt8]
    private var index = 0

    init(_ data: Data) {
        bytes = Array(data)
    }

    /// Следующее поле сообщения или `nil`, если данные закончились.
    mutating func nextField() throws -> (number: Int, value: Value)? {
        guard index < bytes.count else { return nil }
        let key = try readVarint()
        let number = Int(truncatingIfNeeded: key >> 3)

        switch key & 0x07 {
        case 0:
            return (number, .varint(try readVarint()))
        case 1:
            try skip(8)
            return (number, .skipped)
        case 2:
            let length = try readVarint()
            guard length <= UInt64(bytes.count - index) else { throw Failure.truncated }
            let end = index + Int(length)
            defer { index = end }
            return (number, .bytes(Data(bytes[index..<end])))
        case 5:
            try skip(4)
            return (number, .skipped)
        case let wireType:
            throw Failure.unsupportedWireType(wireType)
        }
    }

    private mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while shift < 64 {
            guard index < bytes.count else { throw Failure.truncated }
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw Failure.malformedVarint
    }

    private mutating func skip(_ count: Int) throws {
        guard count <= bytes.count - index else { throw Failure.truncated }
        index += count
    }
}
