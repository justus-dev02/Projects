import SwiftUI
import UniformTypeIdentifiers

/// A file waiting to be saved by the user.
struct PendingExport {
    let document: ExportDocument
    let type: UTType
    let name: String
}

/// A file produced in memory and saved through `fileExporter`.
struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText]

    let data: Data

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
