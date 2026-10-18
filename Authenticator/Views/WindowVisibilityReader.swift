import AppKit
import SwiftUI

/// Сообщает, видно ли окно на экране. Свёрнутое, скрытое вместе с приложением, закрытое другими окнами
/// или оставшееся на другом рабочем столе окно невидимо — обновлять его содержимое незачем.
struct WindowVisibilityReader: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> Observer {
        Observer()
    }

    func updateNSView(_ observer: Observer, context: Context) {
        observer.onChange = { isVisible = $0 }
    }

    final class Observer: NSView {
        var onChange: ((Bool) -> Void)?
        private var tokens: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens = []
            guard let window else { return }
            // Главный сигнал — смена видимости. Активация окна — подстраховка: в окне, с которым работают,
            // коды точно идут.
            tokens = [NSWindow.didChangeOcclusionStateNotification, NSWindow.didBecomeKeyNotification].map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                }
            }
            // Сообщаем, когда SwiftUI закончит обновление, в котором появился наблюдатель.
            Task { @MainActor [weak self] in self?.report() }
        }

        private func report() {
            onChange?(window?.occlusionState.contains(.visible) ?? false)
        }
    }
}
