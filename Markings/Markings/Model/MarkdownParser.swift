//
//  MarkdownParser.swift
//  Markings
//

import Foundation

/// A source line paired with its original line number.
///
/// Nested content is re-parsed after being dedented, so carrying the original
/// number alongside the (possibly rewritten) text is what keeps every parsed
/// block pointing back at the line the user actually typed.
nonisolated struct MarkdownSourceLine {
    var number: Int
    var text: String
}

/// A small, predictable block-level Markdown parser.
///
/// It covers the constructs Markings can author — ATX and Setext headings,
/// paragraphs, fenced code, block quotes, bulleted/ordered/task lists with
/// nesting, GitHub-style tables and thematic breaks — and deliberately stops
/// there. Inline syntax is handed to Foundation's Markdown parser, which is
/// battle-tested and produces the same results the rest of the platform does.
nonisolated enum MarkdownParser {

    static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.components(separatedBy: "\n").enumerated().map {
            MarkdownSourceLine(number: $0.offset, text: $0.element)
        }
        return parse(lines: lines)
    }

    static func parse(lines: [MarkdownSourceLine]) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            if isBlank(lines[index].text) {
                index += 1
                continue
            }
            if let (block, next) = parseFencedCode(lines, index) {
                blocks.append(block)
                index = next
            } else if isThematicBreak(lines[index].text) {
                blocks.append(MarkdownBlock(kind: .thematicBreak,
                                            firstLine: lines[index].number,
                                            lastLine: lines[index].number))
                index += 1
            } else if let block = parseATXHeading(lines[index]) {
                blocks.append(block)
                index += 1
            } else if let (block, next) = parseBlockQuote(lines, index) {
                blocks.append(block)
                index = next
            } else if let (block, next) = parseTable(lines, index) {
                blocks.append(block)
                index = next
            } else if let (block, next) = parseList(lines, index) {
                blocks.append(block)
                index = next
            } else {
                let (block, next) = parseParagraph(lines, index)
                blocks.append(block)
                index = next
            }
        }
        return blocks
    }

    // MARK: - Line classification

    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func leadingSpaces(_ text: String) -> Int {
        text.prefix(while: { $0 == " " }).count
    }

    /// Three or more `-`, `*` or `_`, optionally spaced out.
    static func isThematicBreak(_ text: String) -> Bool {
        guard leadingSpaces(text) <= 3 else { return false }
        let stripped = text.drop(while: { $0 == " " })
        guard let marker = stripped.first, marker == "-" || marker == "*" || marker == "_" else { return false }
        var count = 0
        for character in stripped {
            if character == marker {
                count += 1
            } else if character != " " && character != "\t" {
                return false
            }
        }
        return count >= 3
    }

    /// A run of `=` or `-` underlining the previous line.
    static func setextLevel(_ text: String) -> Int? {
        guard leadingSpaces(text) <= 3 else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.allSatisfy({ $0 == "=" }) { return 1 }
        if trimmed.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }

    static func isQuoteLine(_ text: String) -> Bool {
        guard leadingSpaces(text) <= 3 else { return false }
        return text.drop(while: { $0 == " " }).first == ">"
    }

    /// Describes an opening or closing code fence.
    static func fenceInfo(_ text: String) -> (marker: Character, count: Int, info: String)? {
        guard leadingSpaces(text) <= 3 else { return nil }
        var scan = text.drop(while: { $0 == " " })
        guard let marker = scan.first, marker == "`" || marker == "~" else { return nil }
        var count = 0
        while scan.first == marker {
            count += 1
            scan = scan.dropFirst()
        }
        guard count >= 3 else { return nil }
        let info = scan.trimmingCharacters(in: .whitespaces)
        // An info string on a backtick fence may not contain a backtick.
        if marker == "`" && info.contains("`") { return nil }
        return (marker, count, info)
    }

    // MARK: - Block parsers

    static func parseFencedCode(_ lines: [MarkdownSourceLine], _ start: Int) -> (MarkdownBlock, Int)? {
        guard let open = fenceInfo(lines[start].text) else { return nil }
        let fenceIndent = leadingSpaces(lines[start].text)
        var code: [String] = []
        var index = start + 1

        while index < lines.count {
            if let close = fenceInfo(lines[index].text),
               close.marker == open.marker,
               close.count >= open.count,
               close.info.isEmpty {
                index += 1
                break
            }
            code.append(stripLeadingSpaces(lines[index].text, upTo: fenceIndent))
            index += 1
        }

        let language = open.info.split(separator: " ").first.map(String.init)
        let block = MarkdownBlock(kind: .codeBlock(language: language, code: code.joined(separator: "\n")),
                                  firstLine: lines[start].number,
                                  lastLine: lines[max(index - 1, start)].number)
        return (block, index)
    }

    static func parseATXHeading(_ line: MarkdownSourceLine) -> MarkdownBlock? {
        let parsed = MarkdownLine.parse(line.text)
        guard case .heading(let level) = parsed.kind,
              MarkdownLine.indentWidth(parsed.indent) <= 3 else { return nil }

        var text = parsed.content
        // An optional closing run of hashes is decoration, not content.
        if text.hasSuffix("#") {
            var trimmed = Substring(text)
            while trimmed.last == "#" { trimmed = trimmed.dropLast() }
            if trimmed.isEmpty || trimmed.last == " " {
                text = String(trimmed).trimmingCharacters(in: .whitespaces)
            }
        }
        return MarkdownBlock(kind: .heading(level: level, text: text),
                             firstLine: line.number,
                             lastLine: line.number)
    }

    static func parseBlockQuote(_ lines: [MarkdownSourceLine], _ start: Int) -> (MarkdownBlock, Int)? {
        guard isQuoteLine(lines[start].text) else { return nil }
        var inner: [MarkdownSourceLine] = []
        var index = start

        while index < lines.count, isQuoteLine(lines[index].text) {
            inner.append(MarkdownSourceLine(number: lines[index].number,
                                            text: strippingQuoteMarker(lines[index].text)))
            index += 1
        }

        let block = MarkdownBlock(kind: .blockQuote(blocks: parse(lines: inner)),
                                  firstLine: lines[start].number,
                                  lastLine: lines[index - 1].number)
        return (block, index)
    }

    static func parseTable(_ lines: [MarkdownSourceLine], _ start: Int) -> (MarkdownBlock, Int)? {
        guard start + 1 < lines.count, lines[start].text.contains("|") else { return nil }
        guard let alignments = tableAlignments(lines[start + 1].text) else { return nil }
        let header = tableCells(lines[start].text)
        guard !header.isEmpty, header.count == alignments.count else { return nil }

        var rows: [[String]] = []
        var index = start + 2
        while index < lines.count, lines[index].text.contains("|"), !isBlank(lines[index].text) {
            var cells = tableCells(lines[index].text)
            if cells.count < header.count {
                cells.append(contentsOf: Array(repeating: "", count: header.count - cells.count))
            } else if cells.count > header.count {
                cells = Array(cells.prefix(header.count))
            }
            rows.append(cells)
            index += 1
        }

        let table = MarkdownTable(alignments: alignments, header: header, rows: rows)
        return (MarkdownBlock(kind: .table(table),
                              firstLine: lines[start].number,
                              lastLine: lines[index - 1].number), index)
    }

    static func parseList(_ lines: [MarkdownSourceLine], _ start: Int) -> (MarkdownBlock, Int)? {
        let first = MarkdownLine.parse(lines[start].text)
        guard first.isListItem, MarkdownLine.indentWidth(first.indent) <= 3 else { return nil }

        let baseIndent = MarkdownLine.indentWidth(first.indent)
        let isOrdered = first.isOrdered
        var items: [MarkdownListItem] = []
        var isTaskList = false
        var index = start
        var lastLine = lines[start].number

        while index < lines.count {
            let parsed = MarkdownLine.parse(lines[index].text)
            guard parsed.isListItem,
                  parsed.isOrdered == isOrdered,
                  MarkdownLine.indentWidth(parsed.indent) <= baseIndent + 1 else { break }

            let contentColumn = parsed.contentColumn
            let markerLine = lines[index].number
            var itemLines = [MarkdownSourceLine(number: markerLine, text: parsed.content)]
            if parsed.task != nil { isTaskList = true }

            var scan = index + 1
            var pendingBlanks: [MarkdownSourceLine] = []
            while scan < lines.count {
                if isBlank(lines[scan].text) {
                    pendingBlanks.append(MarkdownSourceLine(number: lines[scan].number, text: ""))
                    scan += 1
                    continue
                }
                let lineIndent = MarkdownLine.indentWidth(MarkdownLine.parse(lines[scan].text).indent)
                guard lineIndent >= contentColumn else { break }
                itemLines.append(contentsOf: pendingBlanks)
                pendingBlanks.removeAll()
                itemLines.append(MarkdownSourceLine(number: lines[scan].number,
                                                    text: dedent(lines[scan].text, by: contentColumn)))
                scan += 1
            }

            let itemEnd = scan - pendingBlanks.count
            items.append(MarkdownListItem(blocks: parse(lines: itemLines),
                                          checked: parsed.task,
                                          markerLine: markerLine,
                                          number: parsed.orderedNumber ?? (items.count + 1)))
            lastLine = lines[max(itemEnd - 1, index)].number
            index = scan
        }

        guard !items.isEmpty else { return nil }
        let list = MarkdownList(isOrdered: isOrdered, isTaskList: isTaskList, items: items)
        return (MarkdownBlock(kind: .list(list), firstLine: lines[start].number, lastLine: lastLine), index)
    }

    static func parseParagraph(_ lines: [MarkdownSourceLine], _ start: Int) -> (MarkdownBlock, Int) {
        if start + 1 < lines.count, let level = setextLevel(lines[start + 1].text) {
            let text = lines[start].text.trimmingCharacters(in: .whitespaces)
            return (MarkdownBlock(kind: .heading(level: level, text: text),
                                  firstLine: lines[start].number,
                                  lastLine: lines[start + 1].number), start + 2)
        }

        var collected: [String] = []
        var index = start
        while index < lines.count {
            let text = lines[index].text
            if isBlank(text) { break }
            if index > start && startsNewBlock(lines, at: index) { break }
            collected.append(text)
            index += 1
        }

        return (MarkdownBlock(kind: .paragraph(text: joinParagraph(collected)),
                              firstLine: lines[start].number,
                              lastLine: lines[max(index - 1, start)].number),
                max(index, start + 1))
    }

    /// Whether a line interrupts the paragraph that precedes it.
    private static func startsNewBlock(_ lines: [MarkdownSourceLine], at index: Int) -> Bool {
        let text = lines[index].text
        if isThematicBreak(text) { return true }
        if fenceInfo(text) != nil { return true }
        if isQuoteLine(text) { return true }
        if index + 1 < lines.count, setextLevel(lines[index + 1].text) != nil { return true }
        let parsed = MarkdownLine.parse(text)
        if case .heading = parsed.kind { return true }
        return parsed.isListItem
    }

    // MARK: - Helpers

    static func strippingQuoteMarker(_ text: String) -> String {
        var rest = text.drop(while: { $0 == " " })
        if rest.first == ">" { rest = rest.dropFirst() }
        if rest.first == " " { rest = rest.dropFirst() }
        return String(rest)
    }

    static func stripLeadingSpaces(_ text: String, upTo columns: Int) -> String {
        var removed = 0
        var rest = Substring(text)
        while removed < columns, rest.first == " " {
            removed += 1
            rest = rest.dropFirst()
        }
        return String(rest)
    }

    static func dedent(_ text: String, by columns: Int) -> String {
        var removed = 0
        var rest = Substring(text)
        while removed < columns, let first = rest.first, first == " " || first == "\t" {
            removed += (first == "\t") ? 4 : 1
            rest = rest.dropFirst()
        }
        return String(rest)
    }

    /// Joins the lines of a paragraph, honouring Markdown hard line breaks
    /// (two trailing spaces, or a trailing backslash).
    static func joinParagraph(_ lines: [String]) -> String {
        var result = ""
        var pendingHardBreak = false
        for (offset, raw) in lines.enumerated() {
            var line = raw
            var hardBreak = line.hasSuffix("  ")
            if line.hasSuffix("\\") {
                hardBreak = true
                line.removeLast()
            }
            line = line.trimmingCharacters(in: .whitespaces)
            if offset == 0 {
                result = line
            } else {
                result += (pendingHardBreak ? "\n" : " ") + line
            }
            pendingHardBreak = hardBreak
        }
        return result
    }

    static func tableCells(_ text: String) -> [String] {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") && !trimmed.hasSuffix("\\|") { trimmed.removeLast() }

        var cells: [String] = []
        var current = ""
        var escaped = false
        for character in trimmed {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                escaped = true
                current.append(character)
                continue
            }
            if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                continue
            }
            current.append(character)
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    static func tableAlignments(_ text: String) -> [MarkdownTableAlignment]? {
        guard text.contains("-") else { return nil }
        let cells = tableCells(text)
        guard !cells.isEmpty else { return nil }

        var alignments: [MarkdownTableAlignment] = []
        for cell in cells {
            var body = Substring(cell)
            guard !body.isEmpty else { return nil }
            let leadingColon = body.first == ":"
            if leadingColon { body = body.dropFirst() }
            let trailingColon = body.last == ":"
            if trailingColon { body = body.dropLast() }
            guard !body.isEmpty, body.allSatisfy({ $0 == "-" }) else { return nil }

            if leadingColon && trailingColon {
                alignments.append(.center)
            } else if trailingColon {
                alignments.append(.trailing)
            } else {
                alignments.append(.leading)
            }
        }
        return alignments
    }
}
