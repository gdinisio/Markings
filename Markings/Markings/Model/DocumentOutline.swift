//
//  DocumentOutline.swift
//  Markings
//

import Foundation

/// One heading in the document outline.
nonisolated struct OutlineItem: Identifiable, Equatable {
    var level: Int
    var title: String
    var line: Int

    var id: Int { line }
}

nonisolated enum DocumentOutline {

    /// Top-level headings, in document order, with inline syntax stripped so
    /// the sidebar reads as prose rather than as source.
    static func items(from blocks: [MarkdownBlock]) -> [OutlineItem] {
        blocks.compactMap { block in
            guard case .heading(let level, let text) = block.kind else { return nil }
            let title = MarkdownInlineText.plainText(text).trimmingCharacters(in: .whitespaces)
            return OutlineItem(level: level,
                               title: title.isEmpty ? "Untitled heading" : title,
                               line: block.firstLine)
        }
    }

    /// The outline item the caret currently sits in, so the sidebar can show
    /// where you are without you having to work it out.
    static func item(containing line: Int, in items: [OutlineItem]) -> OutlineItem? {
        items.last { $0.line <= line }
    }
}
