import AppKit

@MainActor
enum Clipboard {
    private static var clearTask: Task<Void, Never>?

    /// Копирует код и через `clearAfter` очищает буфер, если там всё ещё он.
    static func copySecret(_ string: String, clearAfter delay: Duration = .seconds(30)) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        // Просим менеджеры буфера обмена не сохранять код в истории (соглашение nspasteboard.org).
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        let changeCount = pasteboard.changeCount
        clearTask?.cancel()
        clearTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, pasteboard.changeCount == changeCount else { return }
            pasteboard.clearContents()
        }
    }
}
