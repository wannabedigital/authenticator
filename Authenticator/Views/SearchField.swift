import AppKit
import SwiftUI

/// Состояние строки поиска, которая появляется по сочетанию клавиш.
struct SearchState {
    /// Строка поиска проявляется и растворяется, а содержимое под ней плавно сдвигается.
    static let animation = Animation.smooth(duration: 0.25)

    private(set) var isPresented = false
    var query = ""
    /// Каждое увеличение переводит фокус в поле — в том числе если оно уже открыто.
    private(set) var focusRequest = 0

    mutating func present() {
        isPresented = true
        focusRequest += 1
    }

    mutating func dismiss() {
        isPresented = false
        query = ""
    }
}

/// Системное поле поиска (NSSearchField): родной вид и кнопка очистки.
/// Esc закрывает поиск; если поле теряет фокус с пустым запросом — тоже.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let focusRequest: Int
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> FocusableSearchField {
        let field = FocusableSearchField()
        field.placeholderString = prompt
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchChanged(_:))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.focusWhenAttached = true
        context.coordinator.lastFocusRequest = focusRequest
        return field
    }

    func updateNSView(_ field: FocusableSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            field.focus()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: FocusableSearchField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 220, height: field.intrinsicContentSize.height)
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField
        var lastFocusRequest = 0

        init(_ parent: SearchField) {
            self.parent = parent
        }

        /// Ввод текста и кнопка очистки внутри поля.
        @objc func searchChanged(_ sender: NSSearchField) {
            parent.text = sender.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
            parent.onDismiss()
            return true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField, field.stringValue.isEmpty else { return }
            // Откладываем: редактирование заканчивается и тогда, когда SwiftUI убирает поле с экрана.
            Task { [weak self] in
                self?.parent.onDismiss()
            }
        }
    }
}

final class FocusableSearchField: NSSearchField {
    var focusWhenAttached = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if focusWhenAttached, window != nil {
            focusWhenAttached = false
            focus()
        }
    }

    func focus() {
        guard let window else {
            focusWhenAttached = true
            return
        }
        if let editor = currentEditor() {
            // Уже в фокусе: повторный makeFirstResponder завершил бы редактирование.
            editor.selectAll(nil)
        } else {
            window.makeFirstResponder(self)
        }
    }
}
