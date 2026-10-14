import CoreImage
import CoreImage.CIFilterBuiltins

/// QR-код из текста — системным фильтром CoreImage, на устройстве.
enum QRCodeImage {
    /// Один пиксель на модуль кода: увеличивайте без сглаживания (`interpolation(.none)`).
    static func make(_ text: String, scale: CGFloat = 1) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
