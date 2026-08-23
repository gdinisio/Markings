//
//  HTMLExportDocument.swift
//  Markings
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A throwaway document used only to drive the export save panel.
nonisolated struct HTMLExportDocument: FileDocument {

    var html: String

    init(html: String) {
        self.html = html
    }

    static var readableContentTypes: [UTType] { [.html] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        html = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = html.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
