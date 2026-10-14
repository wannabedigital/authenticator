import Foundation
import Vision

/// Ищет QR-коды на изображении средствами системного фреймворка Vision —
/// распознавание идёт полностью на устройстве.
enum QRCodeScanner {
    static func payloads(in imageData: Data) async throws -> [String] {
        var request = DetectBarcodesRequest()
        request.symbologies = [.qr]
        let observations = try await request.perform(on: imageData)
        return observations.compactMap(\.payloadString)
    }
}
