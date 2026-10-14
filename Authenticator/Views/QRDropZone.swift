import AppKit
import SwiftUI

/// Зона импорта QR-кода: перетаскивание, ⌘V при наведении и выбор файла по клику.
struct QRDropZone: View {
    enum Status: Equatable {
        case scanning
        case success(String)
        case failure(String)
    }

    let status: Status?
    let onImport: ([ImportItem]) async -> Void

    @State private var isTargeted = false
    @State private var isHovering = false
    @State private var isPickingFiles = false
    @State private var pasteMonitor = PasteShortcutMonitor()

    private let cornerRadius: CGFloat = 20
    private var isHighlighted: Bool { isTargeted || isHovering }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(isHighlighted ? Color.accentColor : Color.secondary)
                .symbolEffect(.bounce, value: isTargeted)
            Text("Перетащите QR-код сюда")
                .font(.headline)
            Text("Нажмите, чтобы выбрать файл, или наведите курсор и нажмите ⌘V")
                .font(.caption)
                .foregroundStyle(.secondary)
            statusLine
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(16)
        .contentShape(.rect(cornerRadius: cornerRadius))
        .glassEffect(
            isHighlighted ? .regular.tint(.accentColor.opacity(0.15)).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    isHighlighted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )
        }
        .animation(.easeOut(duration: 0.15), value: isHighlighted)
        .onTapGesture { isPickingFiles = true }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                pasteMonitor.start { importItems(ImportItem.read(from: .general)) }
            } else {
                pasteMonitor.stop()
            }
        }
        .onDisappear { pasteMonitor.stop() }
        .onDrop(of: ImportItem.dropTypes, isTargeted: $isTargeted) { providers in
            Task { await onImport(await ImportItem.load(from: providers)) }
            return true
        }
        .fileImporter(isPresented: $isPickingFiles, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                importItems(urls.map(ImportItem.read))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { isPickingFiles = true }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .scanning:
            ProgressView().controlSize(.small)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
        case nil:
            EmptyView()
        }
    }

    private func importItems(_ items: [ImportItem]) {
        Task {
            var items = items
            let blocked = items.compactMap { item -> URL? in
                if case .unreadable(let url) = item { url } else { nil }
            }
            if !blocked.isEmpty, let granted = await requestAccess(to: blocked) {
                items.removeAll { if case .unreadable = $0 { true } else { false } }
                items += granted.map(ImportItem.read)
            }
            await onImport(items)
        }
    }

    /// Песочница выдаёт доступ к файлу, только если пользователь сам выбрал его в системном окне.
    /// Открываем окно сразу на нужном файле — остаётся нажать «Открыть».
    private func requestAccess(to urls: [URL]) async -> [URL]? {
        let panel = NSOpenPanel()
        panel.message = "Подтвердите доступ к изображению из буфера обмена"
        panel.prompt = "Открыть"
        panel.directoryURL = urls[0]
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        let response = await panel.begin()
        return response == .OK ? panel.urls : nil
    }
}

/// Перехватывает ⌘V, пока курсор над зоной, — даже если фокус ввода в текстовом поле.
@MainActor
private final class PasteShortcutMonitor {
    /// Физическая клавиша V: на русской раскладке символ будет «м».
    private static let vKeyCode: UInt16 = 9
    private var monitor: Any?

    func start(_ action: @escaping @MainActor () -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isV = event.keyCode == Self.vKeyCode || event.charactersIgnoringModifiers?.lowercased() == "v"
            guard modifiers == .command, isV else { return event }
            MainActor.assumeIsolated { action() }
            return nil
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}
