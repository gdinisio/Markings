//
//  DocumentStatistics.swift
//  Markings
//

import Foundation

/// A read-out of what is actually in the document.
///
/// Counts are taken from the *parsed* document rather than the raw source, so
/// syntax characters, code blocks and link targets do not inflate the word
/// count the way a naive split on whitespace would.
nonisolated struct DocumentStatistics: Equatable {
    var words = 0
    var characters = 0
    var charactersExcludingSpaces = 0
    var lines = 0
    var paragraphs = 0
    var headings = 0
    var links = 0
    var images = 0
    var codeBlocks = 0
    var tables = 0
    var tasksTotal = 0
    var tasksCompleted = 0

    /// Rounded up, and never zero: "less than a minute" reads worse than "1 min".
    var readingMinutes: Int {
        max(1, Int((Double(words) / 220.0).rounded(.up)))
    }

    var hasTasks: Bool { tasksTotal > 0 }

    var taskCompletion: Double {
        tasksTotal == 0 ? 0 : Double(tasksCompleted) / Double(tasksTotal)
    }

    static func make(source: String, blocks: [MarkdownBlock]) -> DocumentStatistics {
        var statistics = DocumentStatistics()
        statistics.characters = source.count
        statistics.charactersExcludingSpaces = source.reduce(into: 0) { total, character in
            if !character.isWhitespace { total += 1 }
        }
        statistics.lines = source.isEmpty ? 0 : source.components(separatedBy: "\n").count
        statistics.accumulate(blocks: blocks)
        return statistics
    }

    private mutating func accumulate(blocks: [MarkdownBlock]) {
        for block in blocks {
            switch block.kind {
            case .heading(_, let text):
                headings += 1
                count(inline: text)
            case .paragraph(let text):
                paragraphs += 1
                count(inline: text)
            case .codeBlock:
                codeBlocks += 1
            case .thematicBreak:
                break
            case .blockQuote(let inner):
                accumulate(blocks: inner)
            case .list(let list):
                for item in list.items {
                    if let checked = item.checked {
                        tasksTotal += 1
                        if checked { tasksCompleted += 1 }
                    }
                    accumulate(blocks: item.blocks)
                }
            case .table(let table):
                tables += 1
                for cell in table.header { count(inline: cell) }
                for row in table.rows {
                    for cell in row { count(inline: cell) }
                }
            }
        }
    }

    private mutating func count(inline source: String) {
        links += DocumentStatistics.linkCount(in: source, images: false)
        images += DocumentStatistics.linkCount(in: source, images: true)
        let plain = MarkdownInlineText.plainText(source)
        words += plain.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .count
    }

    /// Counts `[title](target)` spans, optionally only the `![…](…)` image form.
    private static func linkCount(in source: String, images: Bool) -> Int {
        var count = 0
        var index = source.startIndex
        while index < source.endIndex {
            guard let open = source[index...].firstIndex(of: "[") else { break }
            let isImage = open > source.startIndex && source[source.index(before: open)] == "!"
            guard let close = source[open...].firstIndex(of: "]") else { break }
            let afterClose = source.index(after: close)
            if afterClose < source.endIndex, source[afterClose] == "(",
               source[afterClose...].firstIndex(of: ")") != nil {
                if isImage == images { count += 1 }
            }
            index = afterClose
        }
        return count
    }
}
