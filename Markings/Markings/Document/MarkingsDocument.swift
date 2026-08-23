//
//  MarkingsDocument.swift
//  Markings
//
//  Created by Giovanni Di Nisio on 23/08/2026.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {

    /// Markdown, as declared by Daring Fireball and imported by Markings.
    ///
    /// The identifier is declared in `Info.plist` under `UTImportedTypeDeclarations`,
    /// so it resolves whether or not another installed app already owns it.
    nonisolated static var markdownText: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

/// A plain-text Markdown document.
///
/// Markings deliberately stores documents as plain UTF-8 text rather than a
/// proprietary format: a file written in Markings is readable everywhere, and a
/// file written anywhere else is readable in Markings.
nonisolated struct MarkingsDocument: FileDocument {

    /// The Markdown source. Line endings are normalised to `\n` when reading so
    /// that editing, parsing and offset arithmetic only ever deal with one form.
    var text: String

    init(text: String = "") {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [.markdownText, .plainText] }

    static var writableContentTypes: [UTType] { [.markdownText, .plainText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // UTF-8 covers essentially every Markdown file in the wild; falling back
        // to Latin-1 means a stray legacy file opens instead of failing outright.
        guard let string = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        text = MarkingsDocument.normalizingLineEndings(string)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }

    /// Collapses CRLF and lone CR line endings to LF.
    static func normalizingLineEndings(_ string: String) -> String {
        guard string.contains("\r") else { return string }
        return string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
