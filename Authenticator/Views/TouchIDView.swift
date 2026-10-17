import LocalAuthentication
import LocalAuthenticationEmbeddedUI
import SwiftUI

/// Системный значок Touch ID внутри окна. Пока на связанном `LAContext` идёт проверка,
/// macOS показывает её здесь, а не отдельным окном.
///
/// Значок нельзя масштабировать и обрезать: его рисует система, и под трансформацией SwiftUI
/// он пропадает. Размеры — только системные: small — 32 pt, regular — 64 pt, large — 128 pt.
struct TouchIDView: NSViewRepresentable {
    static let side: CGFloat = 32

    let authenticationContext: LAContext
    /// Значок оказался в окне. Проверку, начатую раньше, система сразу отменяет.
    let onAttached: () -> Void

    func makeNSView(context: Context) -> Container {
        let container = Container()
        container.onAttached = onAttached
        let view = LAAuthenticationView(context: authenticationContext, controlSize: .small)
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    func updateNSView(_ container: Container, context: Context) {
        container.onAttached = onAttached
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Container, context: Context) -> CGSize? {
        CGSize(width: Self.side, height: Self.side)
    }

    final class Container: NSView {
        var onAttached: (() -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            // Даём окну закончить раскладку, прежде чем начинать проверку.
            Task { @MainActor [weak self] in self?.onAttached?() }
        }
    }
}
