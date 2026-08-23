//
//  MarkdownLine.swift
//  Markings
//

import Foundation

/// The structural kind of a single Markdown source line.
nonisolated enum MarkdownLineKind: Equatable {
    case paragraph
    case heading(level: Int)
    case bullet(marker: String)
    case ordered(number: Int, delimiter: String)
    case quote(depth: Int)
}

/// A single line of Markdown source split into its leading indent, its block
/// marker and the content that follows.
///
/// Every line-based editing command in Markings goes through this type: parsing
/// a line, changing one facet of it and composing it again keeps round-tripping
/// lossless and keeps the commands themselves small enough to reason about.
nonisolated struct MarkdownLine: Equatable {

    /// Leading whitespace, preserved verbatim so indentation survives a round trip.
    var indent: String
    var kind: MarkdownLineKind
    /// `nil` when the line is not a task item, otherwise its checked state.
    var task: Bool?
    /// Everything after the block marker and checkbox.
    var content: String

    // MARK: - Derived structure

    var isBlank: Bool {
        kind == .paragraph && content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isListItem: Bool {
        switch kind {
        case .bullet, .ordered: return true
        case .paragraph, .heading, .quote: return false
        }
    }

    var isOrdered: Bool {
        if case .ordered = kind { return true }
        return false
    }

    var orderedNumber: Int? {
        if case .ordered(let number, _) = kind { return number }
        return nil
    }

    var orderedDelimiter: String {
        if case .ordered(_, let delimiter) = kind { return delimiter }
        return "."
    }

    var bulletMarker: String {
        if case .bullet(let marker) = kind { return marker }
        return "-"
    }

    /// The visual width of this line's marker, including the trailing space and
    /// any task checkbox.
    var markerWidth: Int {
        let checkbox = (task == nil) ? 0 : 4
        switch kind {
        case .paragraph: return 0
        case .heading(let level): return level + 1
        case .bullet: return 2 + checkbox
        case .ordered(let number, _): return String(number).count + 2 + checkbox
        case .quote(let depth): return max(depth, 1) * 2
        }
    }

    /// The column where this line's content begins — the column that nested
    /// content has to reach to belong to this line.
    var contentColumn: Int {
        MarkdownLine.indentWidth(indent) + markerWidth
    }

    /// The line rebuilt from its parts.
    var composed: String {
        let checkbox = task.map { $0 ? "[x] " : "[ ] " } ?? ""
        switch kind {
        case .paragraph:
            return indent + content
        case .heading(let level):
            return indent + String(repeating: "#", count: min(max(level, 1), 6)) + " " + content
        case .bullet(let marker):
            return indent + marker + " " + checkbox + content
        case .ordered(let number, let delimiter):
            return indent + String(number) + delimiter + " " + checkbox + content
        case .quote(let depth):
            return indent + String(repeating: "> ", count: max(depth, 1)) + content
        }
    }

    // MARK: - Parsing

    /// Measures indentation in columns, expanding tabs the way Markdown does.
    static func indentWidth(_ indent: String) -> Int {
        var width = 0
        for character in indent {
            width += (character == "\t") ? 4 : 1
        }
        return width
    }

    /// Splits a raw source line into its structural parts.
    static func parse(_ line: String) -> MarkdownLine {
        var rest = Substring(line)
        let indentEnd = rest.firstIndex(where: { $0 != " " && $0 != "\t" }) ?? rest.endIndex
        let indent = String(rest[rest.startIndex..<indentEnd])
        rest = rest[indentEnd...]

        if let quote = parseQuote(indent: indent, rest: rest) { return quote }
        if let heading = parseHeading(indent: indent, rest: rest) { return heading }
        if let bullet = parseBullet(indent: indent, rest: rest) { return bullet }
        if let ordered = parseOrdered(indent: indent, rest: rest) { return ordered }

        return MarkdownLine(indent: indent, kind: .paragraph, task: nil, content: String(rest))
    }

    private static func parseQuote(indent: String, rest: Substring) -> MarkdownLine? {
        guard rest.first == ">" else { return nil }
        var scan = rest
        var depth = 0
        while scan.first == ">" {
            depth += 1
            scan = scan.dropFirst()
            if scan.first == " " { scan = scan.dropFirst() }
        }
        return MarkdownLine(indent: indent, kind: .quote(depth: depth), task: nil, content: String(scan))
    }

    private static func parseHeading(indent: String, rest: Substring) -> MarkdownLine? {
        guard rest.first == "#" else { return nil }
        var scan = rest
        var level = 0
        while scan.first == "#" && level < 6 {
            level += 1
            scan = scan.dropFirst()
        }
        // "#####text" is not a heading; the marker needs a space (or nothing) after it.
        guard scan.isEmpty || scan.first == " " else { return nil }
        if scan.first == " " { scan = scan.dropFirst() }
        return MarkdownLine(indent: indent, kind: .heading(level: level), task: nil, content: String(scan))
    }

    private static func parseBullet(indent: String, rest: Substring) -> MarkdownLine? {
        guard let marker = rest.first, marker == "-" || marker == "*" || marker == "+" else { return nil }
        var body = rest.dropFirst()
        // A marker with no space after it is emphasis or a rule, not a list.
        guard body.isEmpty || body.first == " " else { return nil }
        if body.first == " " { body = body.dropFirst() }
        let checkbox = parseCheckbox(&body)
        return MarkdownLine(indent: indent, kind: .bullet(marker: String(marker)), task: checkbox, content: String(body))
    }

    private static func parseOrdered(indent: String, rest: Substring) -> MarkdownLine? {
        guard let first = rest.first, first.isNumber else { return nil }
        var scan = rest
        var digits = ""
        while let character = scan.first, character.isNumber, digits.count < 9 {
            digits.append(character)
            scan = scan.dropFirst()
        }
        guard let delimiter = scan.first, delimiter == "." || delimiter == ")" else { return nil }
        var body = scan.dropFirst()
        guard body.isEmpty || body.first == " " else { return nil }
        if body.first == " " { body = body.dropFirst() }
        let checkbox = parseCheckbox(&body)
        return MarkdownLine(indent: indent,
                            kind: .ordered(number: Int(digits) ?? 1, delimiter: String(delimiter)),
                            task: checkbox,
                            content: String(body))
    }

    /// Consumes a leading `[ ]`, `[x]` or `[X]` checkbox, if present.
    private static func parseCheckbox(_ body: inout Substring) -> Bool? {
        let candidates = ["[ ] ", "[x] ", "[X] "]
        for candidate in candidates where body.hasPrefix(candidate) {
            body = body.dropFirst(candidate.count)
            return candidate != "[ ] "
        }
        for candidate in ["[ ]", "[x]", "[X]"] where body == candidate {
            body = body.dropFirst(candidate.count)
            return candidate != "[ ]"
        }
        return nil
    }
}
