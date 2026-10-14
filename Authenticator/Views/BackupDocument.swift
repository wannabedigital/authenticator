import SwiftUI
import UniformTypeIdentifiers

/// Готовый зашифрованный файл для окна «Сохранить».
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [BackupFile.contentType] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
