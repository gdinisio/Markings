//
//  MarkdownTransforms.swift
//  Markings
//

import Foundation

/// A single contiguous replacement plus the selection that should follow it.
///
/// Every editing command produces exactly one of these. Keeping edits
/// contiguous means they can be handed straight to `NSTextView`, which gives
/// correct undo grouping and accessibility notifications for free.
nonisolated struct TextEdit {
    var range: NSRange
    var replacement: String
    var selection: NSRange
}

/// The paragraph style of the line the caret is on.
nonisolated enum BlockStyle: Hashable {
    case body
    case heading(Int)
    case bulletList
    case numberedList
    case taskList
    case quote

    var title: String {
        switch self {
        case .body: return "Body"
        case .heading(let level): return "Heading \(level)"
        case .bulletList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .taskList: return "Task List"
        case .quote: return "Block Quote"
        }
    }

    var symbolName: String {
        switch self {
        case .body: return "text.alignleft"
        case .heading: return "textformat.size.larger"
        case .bulletList: return "list.bullet"
        case .numberedList: return "list.number"
        case .taskList: return "checklist"
        case .quote: return "text.quote"
        }
    }
}

/// Pure, testable text transformations shared by the toolbar, the menu bar and
/// the editor's own key handling.
///
/// Everything here works on `NSString` and `NSRange` because that is the
/// currency `NSTextView` speaks; converting back and forth to `String.Index`
/// on every keystroke would be both slower and easier to get wrong.
nonisolated enum MarkdownTransforms {

    // MARK: - Line geometry

    /// The range of the whole lines a selection touches, without the trailing newline.
    static func lineRange(in text: NSString, for selection: NSRange) -> NSRange {
        var effective = selection
        // A selection that ends exactly at a line break should not drag the
        // following line into the edit.
        if effective.length > 0,
           NSMaxRange(effective) > 0,
           NSMaxRange(effective) <= text.length,
           text.character(at: NSMaxRange(effective) - 1) == 10 {
            effective.length -= 1
        }
        var range = text.lineRange(for: effective)
        if range.length > 0, text.character(at: NSMaxRange(range) - 1) == 10 {
            range.length -= 1
        }
        return range
    }

    /// The zero-based line number containing `location`.
    static func lineNumber(in text: NSString, at location: Int) -> Int {
        guard location > 0 else { return 0 }
        var number = 0
        var index = 0
        let limit = min(location, text.length)
        while index < limit {
            if text.character(at: index) == 10 { number += 1 }
            index += 1
        }
        return number
    }

    /// The one-based column of `location` within its line.
    static func column(in text: NSString, at location: Int) -> Int {
        let range = text.lineRange(for: NSRange(location: min(location, text.length), length: 0))
        return min(location, text.length) - range.location + 1
    }

    /// The character range of a given line number, without its newline.
    static func range(ofLine number: Int, in text: NSString) -> NSRange? {
        var index = 0
        var line = 0
        while line < number {
            let range = text.lineRange(for: NSRange(location: index, length: 0))
            let next = NSMaxRange(range)
            if next <= index { return nil }
            index = next
            line += 1
            if index >= text.length && line < number { return nil }
        }
        var range = text.lineRange(for: NSRange(location: min(index, text.length), length: 0))
        if range.length > 0, text.character(at: NSMaxRange(range) - 1) == 10 {
            range.length -= 1
        }
        return range
    }

    // MARK: - Applying line transforms

    static func transformRawLines(in text: NSString,
                                  selection: NSRange,
                                  transform: ([String]) -> [String]) -> TextEdit {
        let range = lineRange(in: text, for: selection)
        let oldLines = text.substring(with: range).components(separatedBy: "\n")
        let newLines = transform(oldLines)
        let replacement = newLines.joined(separator: "\n")

        let newSelection: NSRange
        if selection.length == 0 {
            let location = caretLocation(from: oldLines,
                                         to: newLines,
                                         lineStart: range.location,
                                         caret: selection.location)
            newSelection = NSRange(location: location, length: 0)
        } else {
            newSelection = NSRange(location: range.location, length: replacement.utf16.count)
        }
        return TextEdit(range: range, replacement: replacement, selection: newSelection)
    }

    static func transformLines(in text: NSString,
                               selection: NSRange,
                               transform: ([MarkdownLine]) -> [MarkdownLine]) -> TextEdit {
        transformRawLines(in: text, selection: selection) { lines in
            transform(lines.map(MarkdownLine.parse)).map(\.composed)
        }
    }

    /// Keeps the caret on the same line, shifted by however much that line's
    /// prefix grew or shrank.
    private static func caretLocation(from oldLines: [String],
                                      to newLines: [String],
                                      lineStart: Int,
                                      caret: Int) -> Int {
        var start = lineStart
        for (index, old) in oldLines.enumerated() {
            let oldLength = old.utf16.count
            let end = start + oldLength
            if caret <= end || index == oldLines.count - 1 {
                let new = index < newLines.count ? newLines[index] : old
                let newLength = new.utf16.count
                let offset = min(max(caret - start, 0), oldLength)
                let adjusted = min(max(offset + (newLength - oldLength), 0), newLength)
                var newStart = lineStart
                for previous in newLines.prefix(index) {
                    newStart += previous.utf16.count + 1
                }
                return newStart + adjusted
            }
            start = end + 1
        }
        return lineStart
    }

    // MARK: - Block styles

    static func blockStyle(in text: NSString, at selection: NSRange) -> BlockStyle {
        let range = lineRange(in: text, for: NSRange(location: min(selection.location, text.length), length: 0))
        let parsed = MarkdownLine.parse(text.substring(with: range))
        if case .heading(let level) = parsed.kind { return .heading(level) }
        if case .quote = parsed.kind { return .quote }
        if parsed.task != nil { return .taskList }
        if parsed.isOrdered { return .numberedList }
        if parsed.isListItem { return .bulletList }
        return .body
    }

    static func apply(_ style: BlockStyle, in text: NSString, selection: NSRange) -> TextEdit {
        switch style {
        case .body: return setBody(in: text, selection: selection)
        case .heading(let level): return setHeading(level: level, in: text, selection: selection)
        case .bulletList: return toggleBulletList(in: text, selection: selection)
        case .numberedList: return toggleNumberedList(in: text, selection: selection)
        case .taskList: return toggleTaskList(in: text, selection: selection)
        case .quote: return toggleBlockQuote(in: text, selection: selection)
        }
    }

    static func setBody(in text: NSString, selection: NSRange) -> TextEdit {
        transformLines(in: text, selection: selection) { lines in
            lines.map { line in
                guard !line.isBlank else { return line }
                var updated = line
                updated.kind = .paragraph
                updated.task = nil
                return updated
            }
        }
    }

    static func setHeading(level: Int, in text: NSString, selection: NSRange) -> TextEdit {
        transformLines(in: text, selection: selection) { lines in
            let candidates = lines.filter { !$0.isBlank }
            let alreadySet = !candidates.isEmpty && candidates.allSatisfy { $0.kind == .heading(level: level) }
            return lines.map { line in
                guard !line.isBlank else { return line }
                var updated = line
                updated.task = nil
                updated.kind = alreadySet ? .paragraph : .heading(level: level)
                return updated
            }
        }
    }

    static func toggleBulletList(in text: NSString, selection: NSRange) -> TextEdit {
        transformLines(in: text, selection: selection) { lines in
            let candidates = lines.filter { !$0.isBlank }
            let allBullets = !candidates.isEmpty && candidates.allSatisfy { line in
                if case .bullet = line.kind { return line.task == nil }
                return false
            }
            return lines.map { line in
                guard !line.isBlank else { return line }
                var updated = line
                updated.task = nil
                updated.kind = allBullets ? .paragraph : .bullet(marker: "-")
                return updated
            }
        }
    }

    static func toggleNumberedList(in text: NSString, selection: NSRange) -> TextEdit {
        transformLines(in: text, selection: selection) { lines in
            let candidates = lines.filter { !$0.isBlank }
            let allOrdered = !candidates.isEmpty && candidates.allSatisfy { $0.isOrdered && $0.task == nil }
            var counter = 0
            return lines.map { line in
                guard !line.isBlank else { return line }
                var updated = line
                updated.task = nil
                if allOrdered {
                    updated.kind = .paragraph
                } else {
                    counter += 1
                    updated.kind = .ordered(number: counter, delimiter: ".")
                }
                return updated
            }
        }
    }

    static func toggleTaskList(in text: NSString, selection: NSRange) -> TextEdit {
        transformLines(in: text, selection: selection) { lines in
            let candidates = lines.filter { !$0.isBlank }
            let allTasks = !candidates.isEmpty && candidates.allSatisfy { $0.task != nil }
            return lines.map { line in
                guard !line.isBlank else { return line }
                var updated = line
                if allTasks {
                    updated.task = nil
                } else {
                    if !updated.isListItem { updated.kind = .bullet(marker: "-") }
                    updated.task = false
                }
                return updated
            }
        }
    }

    static func toggleBlockQuote(in text: NSString, selection: NSRange) -> TextEdit {
        transformRawLines(in: text, selection: selection) { lines in
            let candidates = lines.filter { !MarkdownParser.isBlank($0) }
            let allQuoted = !candidates.isEmpty && candidates.allSatisfy(MarkdownParser.isQuoteLine)
            return lines.map { line in
                let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
                if allQuoted {
                    guard MarkdownParser.isQuoteLine(line) else { return line }
                    return indent + MarkdownParser.strippingQuoteMarker(line)
                }
                guard !MarkdownParser.isBlank(line) else { return line }
                return indent + "> " + line.dropFirst(indent.count)
            }
        }
    }

    // MARK: - Tasks

    /// Flips the checked state of every task item the selection touches.
    static func toggleTaskCompletion(in text: NSString, selection: NSRange) -> TextEdit? {
        let range = lineRange(in: text, for: selection)
        let parsed = text.substring(with: range).components(separatedBy: "\n").map(MarkdownLine.parse)
        guard parsed.contains(where: { $0.task != nil }) else { return nil }

        return transformLines(in: text, selection: selection) { lines in
            let tasks = lines.filter { $0.task != nil }
            let allChecked = tasks.allSatisfy { $0.task == true }
            return lines.map { line in
                guard line.task != nil else { return line }
                var updated = line
                updated.task = !allChecked
                return updated
            }
        }
    }

    /// Flips one task by source line — used by the checkboxes in the preview.
    static func toggleTask(atLine number: Int, in source: String) -> String? {
        var lines = source.components(separatedBy: "\n")
        guard lines.indices.contains(number) else { return nil }
        var parsed = MarkdownLine.parse(lines[number])
        guard let task = parsed.task else { return nil }
        parsed.task = !task
        lines[number] = parsed.composed
        return lines.joined(separator: "\n")
    }

    // MARK: - Indentation

    static func indent(in text: NSString, selection: NSRange, tabWidth: Int) -> TextEdit {
        let range = lineRange(in: text, for: selection)
        let firstLine = MarkdownLine.parse(text.substring(with: text.lineRange(for: NSRange(location: range.location, length: 0))))
        let current = MarkdownLine.indentWidth(firstLine.indent)
        let previous = previousNonBlankLine(in: text, before: range.location)
        var delta = tabWidth
        if let previous {
            let parsed = MarkdownLine.parse(previous)
            if parsed.isListItem, parsed.contentColumn > current {
                delta = parsed.contentColumn - current
            }
        }
        return shiftIndent(by: delta, in: text, selection: selection)
    }

    /// Returns `nil` when there is nothing to outdent, so the caller can leave
    /// the document — and the undo stack — untouched.
    static func outdent(in text: NSString, selection: NSRange, tabWidth: Int) -> TextEdit? {
        let range = lineRange(in: text, for: selection)
        let firstLine = MarkdownLine.parse(text.substring(with: text.lineRange(for: NSRange(location: range.location, length: 0))))
        let current = MarkdownLine.indentWidth(firstLine.indent)
        guard current > 0 else { return nil }

        var delta = -min(current, tabWidth)
        if let shallower = nearestLine(in: text, before: range.location, indentLessThan: current) {
            let parsed = MarkdownLine.parse(shallower)
            if parsed.isListItem {
                delta = MarkdownLine.indentWidth(parsed.indent) - current
            }
        }
        return shiftIndent(by: delta, in: text, selection: selection)
    }

    static func shiftIndent(by delta: Int, in text: NSString, selection: NSRange) -> TextEdit {
        transformRawLines(in: text, selection: selection) { lines in
            lines.map { line in
                if MarkdownParser.isBlank(line) && delta >= 0 { return line }
                let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
                let rest = line.dropFirst(indent.count)
                let width = max(0, MarkdownLine.indentWidth(indent) + delta)
                return String(repeating: " ", count: width) + rest
            }
        }
    }

    // MARK: - Moving and promoting lines

    /// Moves the lines the selection touches up or down by one line.
    ///
    /// Returns `nil` at the ends of the document so the command is simply
    /// unavailable rather than silently doing nothing to the undo stack.
    static func moveLines(by offset: Int, in text: NSString, selection: NSRange) -> TextEdit? {
        guard offset != 0 else { return nil }
        let block = lineRange(in: text, for: selection)
        let caretOffset = selection.location - block.location

        if offset < 0 {
            guard block.location > 0 else { return nil }
            let previous = lineRange(in: text, for: NSRange(location: block.location - 1, length: 0))
            let combined = NSRange(location: previous.location,
                                   length: NSMaxRange(block) - previous.location)
            let replacement = text.substring(with: block) + "\n" + text.substring(with: previous)
            return TextEdit(range: combined,
                            replacement: replacement,
                            selection: NSRange(location: previous.location + caretOffset,
                                               length: selection.length))
        }

        let separator = NSMaxRange(block)
        guard separator < text.length, separator + 1 < text.length else { return nil }
        let next = lineRange(in: text, for: NSRange(location: separator + 1, length: 0))
        let combined = NSRange(location: block.location, length: NSMaxRange(next) - block.location)
        let nextText = text.substring(with: next)
        let replacement = nextText + "\n" + text.substring(with: block)
        return TextEdit(range: combined,
                        replacement: replacement,
                        selection: NSRange(location: block.location + nextText.utf16.count + 1 + caretOffset,
                                           length: selection.length))
    }

    /// Promotes or demotes headings on the selected lines.
    ///
    /// `delta` is negative to raise (Heading 2 becomes Heading 1). Raising body
    /// text makes it a Heading 1; lowering past Heading 6 returns it to body.
    /// List items and quotes are left alone — changing those is a different
    /// decision, and one the Format menu already offers.
    static func changeHeadingLevel(by delta: Int, in text: NSString, selection: NSRange) -> TextEdit? {
        let edit = transformLines(in: text, selection: selection) { lines in
            lines.map { line in
                guard !line.isBlank else { return line }
                var updated = line
                switch line.kind {
                case .heading(let level):
                    let target = level + delta
                    if target < 1 { return line }
                    if target > 6 {
                        updated.kind = .paragraph
                    } else {
                        updated.kind = .heading(level: target)
                    }
                case .paragraph:
                    guard delta < 0 else { return line }
                    updated.kind = .heading(level: 1)
                    updated.task = nil
                case .bullet, .ordered, .quote:
                    return line
                }
                return updated
            }
        }
        // Nothing to do at the ends of the scale; do not spend an undo step on it.
        guard edit.replacement != text.substring(with: edit.range) else { return nil }
        return edit
    }

    // MARK: - Return key

    /// Continues lists, task lists and block quotes; ends them when the item is
    /// empty; and otherwise preserves the current line's indentation.
    static func newlineContinuation(in text: NSString, selection: NSRange) -> TextEdit? {
        guard selection.length == 0 else { return nil }
        let range = lineRange(in: text, for: selection)
        let raw = text.substring(with: range)
        let parsed = MarkdownLine.parse(raw)
        let markerLength = raw.utf16.count - parsed.content.utf16.count
        let caretOffset = selection.location - range.location
        guard caretOffset >= markerLength else { return nil }

        let isContinuable = parsed.isListItem || {
            if case .quote = parsed.kind { return true }
            return false
        }()

        if isContinuable {
            if parsed.content.trimmingCharacters(in: .whitespaces).isEmpty {
                // Returning on an empty item ends the list instead of adding another.
                return TextEdit(range: range,
                                replacement: "",
                                selection: NSRange(location: range.location, length: 0))
            }
            var next = parsed
            next.content = ""
            if case .ordered(let number, let delimiter) = parsed.kind {
                next.kind = .ordered(number: number + 1, delimiter: delimiter)
            }
            if next.task != nil { next.task = false }
            let replacement = "\n" + next.composed
            return TextEdit(range: NSRange(location: selection.location, length: 0),
                            replacement: replacement,
                            selection: NSRange(location: selection.location + replacement.utf16.count, length: 0))
        }

        if parsed.kind == .paragraph, !parsed.indent.isEmpty {
            let replacement = "\n" + parsed.indent
            return TextEdit(range: NSRange(location: selection.location, length: 0),
                            replacement: replacement,
                            selection: NSRange(location: selection.location + replacement.utf16.count, length: 0))
        }
        return nil
    }

    // MARK: - Inline styles

    /// Wraps, unwraps or toggles a symmetric inline marker such as `**` or a backtick.
    static func toggleInline(marker: String, in text: NSString, selection: NSRange) -> TextEdit {
        var range = selection
        if range.length == 0 { range = wordRange(in: text, at: range.location) }
        range = trimmingWhitespace(in: text, range: range)

        let markerLength = marker.utf16.count
        let inner = text.substring(with: range)

        // Already wrapped inside the selection: unwrap.
        if inner.utf16.count >= markerLength * 2, inner.hasPrefix(marker), inner.hasSuffix(marker) {
            let stripped = String(inner.dropFirst(marker.count).dropLast(marker.count))
            return TextEdit(range: range,
                            replacement: stripped,
                            selection: NSRange(location: range.location, length: stripped.utf16.count))
        }

        // Wrapped just outside the selection: unwrap those markers instead.
        let outerStart = range.location - markerLength
        let outerEnd = NSMaxRange(range) + markerLength
        if outerStart >= 0, outerEnd <= text.length {
            let before = text.substring(with: NSRange(location: outerStart, length: markerLength))
            let after = text.substring(with: NSRange(location: NSMaxRange(range), length: markerLength))
            if before == marker, after == marker {
                return TextEdit(range: NSRange(location: outerStart, length: outerEnd - outerStart),
                                replacement: inner,
                                selection: NSRange(location: outerStart, length: inner.utf16.count))
            }
        }

        let replacement = marker + inner + marker
        let selectionStart = range.location + markerLength
        return TextEdit(range: range,
                        replacement: replacement,
                        selection: NSRange(location: selectionStart, length: inner.utf16.count))
    }

    /// Wraps a selection in a pair of characters, e.g. typing `(` over a selection.
    static func wrap(opening: String, closing: String, in text: NSString, selection: NSRange) -> TextEdit {
        let inner = text.substring(with: selection)
        return TextEdit(range: selection,
                        replacement: opening + inner + closing,
                        selection: NSRange(location: selection.location + opening.utf16.count,
                                           length: inner.utf16.count))
    }

    // MARK: - Insertions

    static func insertLink(isImage: Bool, in text: NSString, selection: NSRange) -> TextEdit {
        let selected = selection.length > 0 ? text.substring(with: selection) : ""
        let bang = isImage ? "!" : ""

        if selected.isEmpty {
            let replacement = bang + "[]()"
            return TextEdit(range: selection,
                            replacement: replacement,
                            selection: NSRange(location: selection.location + bang.utf16.count + 1, length: 0))
        }

        if looksLikeURL(selected) {
            let replacement = "\(bang)[](\(selected))"
            return TextEdit(range: selection,
                            replacement: replacement,
                            selection: NSRange(location: selection.location + bang.utf16.count + 1, length: 0))
        }

        let placeholder = "https://"
        let replacement = "\(bang)[\(selected)](\(placeholder))"
        let urlStart = selection.location + bang.utf16.count + 1 + selected.utf16.count + 2
        return TextEdit(range: selection,
                        replacement: replacement,
                        selection: NSRange(location: urlStart, length: placeholder.utf16.count))
    }

    static func looksLikeURL(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return false }
        return trimmed.contains("://")
            || trimmed.hasPrefix("mailto:")
            || trimmed.hasPrefix("www.")
    }

    /// Inserts a whole block on its own lines, keeping blank-line separation intact.
    static func insertBlock(_ block: String,
                            selectionInBlock: NSRange,
                            in text: NSString,
                            selection: NSRange) -> TextEdit {
        let caret = min(selection.location, text.length)
        let currentLine = lineRange(in: text, for: NSRange(location: caret, length: 0))
        let lineIsBlank = MarkdownParser.isBlank(text.substring(with: currentLine))

        let replaceRange: NSRange
        let prefix: String
        if lineIsBlank {
            replaceRange = currentLine
            prefix = ""
        } else {
            replaceRange = NSRange(location: NSMaxRange(currentLine), length: 0)
            prefix = "\n\n"
        }

        var suffix = ""
        let tail = NSMaxRange(replaceRange)
        if tail < text.length {
            let nextStart = tail + 1
            if nextStart < text.length {
                let nextRange = text.lineRange(for: NSRange(location: nextStart, length: 0))
                var nextLine = text.substring(with: nextRange)
                if nextLine.hasSuffix("\n") { nextLine.removeLast() }
                if !MarkdownParser.isBlank(nextLine) { suffix = "\n" }
            }
        }

        let replacement = prefix + block + suffix
        let selectionStart = replaceRange.location + prefix.utf16.count + selectionInBlock.location
        return TextEdit(range: replaceRange,
                        replacement: replacement,
                        selection: NSRange(location: selectionStart, length: selectionInBlock.length))
    }

    static func insertCodeBlock(language: String = "", in text: NSString, selection: NSRange) -> TextEdit {
        if selection.length > 0 {
            let range = lineRange(in: text, for: selection)
            let body = text.substring(with: range)
            let replacement = "```\(language)\n\(body)\n```"
            return TextEdit(range: range,
                            replacement: replacement,
                            selection: NSRange(location: range.location + 4 + language.utf16.count,
                                               length: body.utf16.count))
        }
        let block = "```\(language)\n\n```"
        // Caret lands on the empty line between the fences.
        let caret = NSRange(location: 4 + language.utf16.count, length: 0)
        return insertBlock(block, selectionInBlock: caret, in: text, selection: selection)
    }

    static func insertThematicBreak(in text: NSString, selection: NSRange) -> TextEdit {
        insertBlock("---", selectionInBlock: NSRange(location: 3, length: 0), in: text, selection: selection)
    }

    static func insertTable(columns: Int = 3, rows: Int = 2, in text: NSString, selection: NSRange) -> TextEdit {
        let header = "| " + (1...columns).map { "Column \($0)" }.joined(separator: " | ") + " |"
        let divider = "| " + Array(repeating: "---", count: columns).joined(separator: " | ") + " |"
        let body = (0..<rows).map { _ in
            "| " + Array(repeating: "   ", count: columns).joined(separator: " | ") + " |"
        }
        let block = ([header, divider] + body).joined(separator: "\n")
        // Select the first column heading so it can be replaced immediately.
        return insertBlock(block, selectionInBlock: NSRange(location: 2, length: 8), in: text, selection: selection)
    }

    // MARK: - Ranges

    static func wordRange(in text: NSString, at location: Int) -> NSRange {
        guard text.length > 0 else { return NSRange(location: location, length: 0) }
        let wordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-'"))
        var start = min(location, text.length)
        var end = start
        while start > 0, let scalar = scalar(text, start - 1), wordCharacters.contains(scalar) { start -= 1 }
        while end < text.length, let scalar = scalar(text, end), wordCharacters.contains(scalar) { end += 1 }
        return NSRange(location: start, length: end - start)
    }

    static func trimmingWhitespace(in text: NSString, range: NSRange) -> NSRange {
        var start = range.location
        var end = NSMaxRange(range)
        let whitespace = CharacterSet.whitespacesAndNewlines
        while start < end, let scalar = scalar(text, start), whitespace.contains(scalar) { start += 1 }
        while end > start, let scalar = scalar(text, end - 1), whitespace.contains(scalar) { end -= 1 }
        return NSRange(location: start, length: end - start)
    }

    private static func scalar(_ text: NSString, _ index: Int) -> Unicode.Scalar? {
        guard index >= 0, index < text.length else { return nil }
        return Unicode.Scalar(text.character(at: index))
    }

    private static func previousNonBlankLine(in text: NSString, before location: Int) -> String? {
        nearestLine(in: text, before: location, indentLessThan: Int.max)
    }

    /// Walks backwards for the closest non-blank line indented less than `limit`.
    private static func nearestLine(in text: NSString, before location: Int, indentLessThan limit: Int) -> String? {
        guard location > 0 else { return nil }
        var probe = location - 1
        var visited = 0
        while probe >= 0 && visited < 512 {
            visited += 1
            let range = text.lineRange(for: NSRange(location: probe, length: 0))
            var content = text.substring(with: range)
            if content.hasSuffix("\n") { content.removeLast() }
            if !MarkdownParser.isBlank(content) {
                let indent = MarkdownLine.indentWidth(MarkdownLine.parse(content).indent)
                if indent < limit { return content }
            }
            if range.location == 0 { return nil }
            probe = range.location - 1
        }
        return nil
    }
}
