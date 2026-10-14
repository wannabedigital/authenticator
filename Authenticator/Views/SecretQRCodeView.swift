import AppKit
import SwiftUI

/// QR-код с секретом. Пока вы в другом приложении, код скрыт.
struct SecretQRCodeView: View {
    let text: String

    @State private var isAppActive = NSApp.isActive

    var body: some View {
        Group {
            if isAppActive, let image = QRCodeImage.make(text) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .background(.white, in: .rect(cornerRadius: 18))
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.quaternary)
                    .overlay {
                        Label("Код скрыт, пока приложение неактивно", systemImage: "eye.slash")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 300, height: 300)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in isAppActive = false }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in isAppActive = true }
    }
}
