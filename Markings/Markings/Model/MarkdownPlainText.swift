//
//  MarkdownPlainText.swift
//  Markings
//

import Foundation

/// Renders a parsed document as readable plain text with the syntax removed.
///
/// This is what "Copy as Plain Text" produces: something you can paste into a
/// message or a note and have it read properly, rather than a wall of asterisks.
/// Structure is kept where plain text can carry it — bullets, numbering,
/// checkboxes, indentation and tab-separated table rows, which paste straight
/// into a spreadsheet.
nonisolated enum MarkdownPlainText {

    static func render(_ blocks: [MarkdownBlock]) -> String {
        paragraphs(from: blocks).joined(separator: "\n\n")
    }

    private static func paragraphs(from blocks: [MarkdownBlock], indent: String = "") -> [String] {
        blocks.flatMap { block -> [String] in
            switch block.kind {
            case .heading(_, let text):
                return [indent + MarkdownInlineText.plainText(text)]

            case .paragraph(let text):
                return [indent + MarkdownInlineText.plainText(text)]

            case .codeBlock(_, let code):
                return [code.components(separatedBy: "\n").map { indent + $0 }.joined(separator: "\n")]

            case .thematicBreak:
                return [indent + "———"]

            case .blockQuote(let inner):
                return paragraphs(from: inner, indent: indent + "    ")

            case .list(let list):
                return [lines(from: list, indent: indent).joined(separator: "\n")]

            case .table(let table):
                let header = table.header.map(MarkdownInlineText.plainText).joined(separator: "\t")
                let rows = table.rows.map { row in
                    row.map(MarkdownInlineText.plainText).joined(separator: "\t")
                }
                return [([header] + rows).map { indent + $0 }.joined(separator: "\n")]
            }
        }
    }

    /// Lists stay one paragraph so their items are not blown apart by blank lines.
    private static func lines(from list: MarkdownList, indent: String) -> [String] {
        list.items.flatMap { item -> [String] in
            let marker: String
            switch item.checked {
            case .some(true): marker = "☑ "
            case .some(false): marker = "☐ "
            case .none: marker = list.isOrdered ? "\(item.number). " : "• "
            }

            var rendered: [String] = []
            for (offset, block) in item.blocks.enumerated() {
                if case .list(let nested) = block.kind {
                    rendered.append(contentsOf: lines(from: nested, indent: indent + "    "))
                    continue
                }
                let body = paragraphs(from: [block]).joined(separator: "\n")
                // Only the item's first line carries the marker; the rest line
                // up underneath it.
                let prefix = (offset == 0) ? indent + marker : indent + String(repeating: " ", count: marker.count)
                rendered.append(prefix + body)
            }
            return rendered.isEmpty ? [indent + marker] : rendered
        }
    }
}
