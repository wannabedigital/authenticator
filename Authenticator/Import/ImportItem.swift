import AppKit
import UniformTypeIdentifiers

/// То, что пользователь перетащил, вставил или выбрал в обзоре файлов.
enum ImportItem {
    case image(Data)
    case text(String)
    /// Файл есть, но прочитать его не удалось: например, Telegram кладёт в буфер обмена
    /// ссылку на файл в своём кэше, а песочница не даёт читать чужие папки.
    case unreadable(URL)

    static let dropTypes: [UTType] = [.image, .fileURL, .plainText]

    // MARK: Перетаскивание

    static func load(from providers: [NSItemProvider]) async -> [ImportItem] {
        var items: [ImportItem] = []
        for provider in providers {
            if let item = await load(from: provider) {
                items.append(item)
            }
        }
        return items
    }

    private static func load(from provider: NSItemProvider) async -> ImportItem? {
        // Картинка напрямую (Telegram, Safari, Фото) или файл-картинка из Finder.
        if let type = provider.registeredContentTypes.first(where: { $0.conforms(to: .image) }),
           let data = await loadData(from: provider, type: type) {
            return .image(data)
        }
        if provider.canLoadObject(ofClass: URL.self), let url = await loadURL(from: provider), url.isFileURL {
            return read(url)
        }
        if provider.canLoadObject(ofClass: String.self), let text = await loadString(from: provider) {
            return .text(text)
        }
        return nil
    }

    private static func loadData(from provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: type) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private static func loadString(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }

    // MARK: Буфер обмена

    static func read(from pasteboard: NSPasteboard) -> [ImportItem] {
        // Файлы, скопированные в Finder (⌘C). Проверяем первыми: вместе с ними
        // в буфере лежит ещё и картинка — иконка файла, она нам не нужна.
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if !urls.isEmpty {
            return urls.map(read)
        }
        // Скопированная картинка («Скопировать изображение» в Telegram, браузере, скриншот в буфер).
        if let type = pasteboard.types?.first(where: { UTType($0.rawValue)?.conforms(to: .image) == true }),
           let data = pasteboard.data(forType: type) {
            return [.image(data)]
        }
        if let text = pasteboard.string(forType: .string) {
            return [.text(text)]
        }
        return []
    }

    // MARK: Файлы

    /// Читает файл, выбранный пользователем, с учётом прав песочницы.
    static func read(_ url: URL) -> ImportItem {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return .unreadable(url) }
        return .image(data)
    }
}
