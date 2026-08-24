//
//  MarkdownSyntaxHighlighter.swift
//  Markings
//

import AppKit
import Foundation

/// Styles Markdown source in place so the editor reads like the document it
/// describes: headings look like headings, quotes recede, code is monospaced,
/// and the syntax characters themselves stay visible but quiet.
///
/// Block structure is walked line by line — which also keeps fenced code
/// tracking exact — and inline spans are found with regular expressions that
/// skip anything already claimed by code.
final class MarkdownSyntaxHighlighter {

    /// Above this many characters the inline passes are skipped. Block-level
    /// styling still applies, so a very large file stays readable and, more
    /// importantly, stays responsive.
    private static let inlineHighlightLimit = 400_000

    private let configuration: EditorConfiguration
    let fonts: EditorFontSet
    let baseAttributes: [NSAttributedString.Key: Any]

    init(configuration: EditorConfiguration) {
        self.configuration = configuration
        self.fonts = EditorFontSet.make(family: configuration.fontFamily,
                                        size: CGFloat(configuration.fontSize))

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = CGFloat(configuration.lineHeight)
        paragraph.paragraphSpacing = CGFloat(configuration.fontSize) * 0.35
        self.baseAttributes = [
            .font: fonts.regular,
            .foregroundColor: EditorTheme.text,
            .paragraphStyle: paragraph
        ]
    }

    // MARK: - Entry point

    /// - Parameter caretLocation: where the caret is. Two things depend on it:
    ///   which paragraph keeps its syntax markers visible, and — when Focus
    ///   Mode is on — which paragraph stays lit while the rest dims.
    func highlight(_ storage: NSTextStorage, caretLocation: Int?) {
        let text = storage.string as NSString
        let full = NSRange(location: 0, length: text.length)
        let activeParagraph = activeParagraph(in: text, caretLocation: caretLocation)

        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: full)

        var codeRanges: [NSRange] = []
        var openFence: (marker: Character, count: Int)?

        text.enumerateSubstrings(in: full, options: [.byLines]) { substring, lineRange, enclosingRange, _ in
            let line = substring ?? ""

            if let fence = MarkdownParser.fenceInfo(line) {
                if let open = openFence {
                    if fence.marker == open.marker, fence.count >= open.count, fence.info.isEmpty {
                        openFence = nil
                    }
                } else {
                    openFence = (fence.marker, fence.count)
                }
                self.styleCodeLine(storage, range: enclosingRange, isFence: true)
                codeRanges.append(enclosingRange)
                return
            }

            if openFence != nil {
                self.styleCodeLine(storage, range: enclosingRange, isFence: false)
                codeRanges.append(enclosingRange)
                return
            }

            self.styleLine(storage,
                           text: text,
                           line: line,
                           lineRange: lineRange,
                           enclosingRange: enclosingRange,
                           isActive: self.intersectsActive(lineRange, activeParagraph))
        }

        if text.length <= Self.inlineHighlightLimit {
            styleInlineSpans(storage, text: text, protectedRanges: codeRanges, activeParagraph: activeParagraph)
        }

        if configuration.focusMode, let caretLocation {
            dimOutsideParagraph(storage, text: text, focusLocation: caretLocation)
        }

        storage.endEditing()
    }

    /// The paragraph whose markers stay at full strength, or `nil` when every
    /// marker should be shown.
    private func activeParagraph(in text: NSString, caretLocation: Int?) -> NSRange? {
        guard configuration.syntaxVisibility == .currentLine, let caretLocation else { return nil }
        return text.paragraphRange(for: NSRange(location: min(caretLocation, text.length), length: 0))
    }

    private func intersectsActive(_ range: NSRange, _ active: NSRange?) -> Bool {
        guard let active else { return true }
        // A caret sitting at the very start or end of a line still counts as
        // being on it, so a zero-length intersection is not enough on its own.
        return NSIntersectionRange(range, active).length > 0
            || (range.location >= active.location && NSMaxRange(range) <= NSMaxRange(active))
    }

    /// Markers recede to a ghost of themselves away from the caret: the source
    /// reads as the finished document, and nothing moves when they come back,
    /// because they never stopped occupying their space.
    private func syntaxColor(isActive: Bool) -> NSColor {
        isActive ? EditorTheme.syntax : EditorTheme.fadedSyntax
    }

    // MARK: - Block level

    private func styleCodeLine(_ storage: NSTextStorage, range: NSRange, isFence: Bool) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = CGFloat(configuration.lineHeight)
        storage.addAttributes([
            .font: fonts.monospaced,
            .foregroundColor: isFence ? EditorTheme.fadedSyntax : EditorTheme.codeText,
            .backgroundColor: EditorTheme.codeBackground,
            .paragraphStyle: paragraph
        ], range: range)
    }

    private func styleLine(_ storage: NSTextStorage,
                           text: NSString,
                           line: String,
                           lineRange: NSRange,
                           enclosingRange: NSRange,
                           isActive: Bool) {
        let parsed = MarkdownLine.parse(line)
        let markerLength = max(0, line.utf16.count - parsed.content.utf16.count)
        let markerRange = NSRange(location: lineRange.location, length: markerLength)
        let contentRange = NSRange(location: lineRange.location + markerLength,
                                   length: max(0, lineRange.length - markerLength))

        // Hanging indent: wrapped lines line up under the item's text rather
        // than sliding back under its bullet.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = CGFloat(configuration.lineHeight)
        paragraph.paragraphSpacing = CGFloat(configuration.fontSize) * 0.35
        if markerLength > 0 {
            let prefix = text.substring(with: markerRange) as NSString
            paragraph.headIndent = prefix.size(withAttributes: [.font: fonts.regular]).width
        }
        if case .heading = parsed.kind {
            paragraph.paragraphSpacingBefore = CGFloat(configuration.fontSize) * 0.7
        }
        storage.addAttribute(.paragraphStyle, value: paragraph, range: enclosingRange)

        switch parsed.kind {
        case .heading(let level):
            storage.addAttribute(.font,
                                 value: fonts.heading(level: level, baseSize: CGFloat(configuration.fontSize)),
                                 range: lineRange)
            storage.addAttribute(.foregroundColor, value: syntaxColor(isActive: isActive), range: markerRange)

        case .quote:
            storage.addAttribute(.foregroundColor, value: EditorTheme.secondaryText, range: lineRange)
            storage.addAttribute(.foregroundColor,
                                 value: isActive ? EditorTheme.accent : EditorTheme.fadedAccent,
                                 range: markerRange)

        case .bullet, .ordered:
            storage.addAttribute(.foregroundColor, value: EditorTheme.accent, range: markerRange)
            if parsed.task == true, contentRange.length > 0 {
                storage.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: EditorTheme.completedTask
                ], range: contentRange)
            }

        case .paragraph:
            if MarkdownParser.isThematicBreak(line) {
                storage.addAttribute(.foregroundColor, value: syntaxColor(isActive: isActive), range: lineRange)
            } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                // Monospacing table source is what makes the columns line up
                // while you are editing them.
                storage.addAttribute(.font, value: fonts.monospaced, range: lineRange)
            }
        }
    }

    private func dimOutsideParagraph(_ storage: NSTextStorage, text: NSString, focusLocation: Int) {
        let paragraph = text.paragraphRange(for: NSRange(location: min(focusLocation, text.length), length: 0))
        let before = NSRange(location: 0, length: paragraph.location)
        let afterStart = NSMaxRange(paragraph)
        let after = NSRange(location: afterStart, length: max(0, text.length - afterStart))
        if before.length > 0 {
            storage.addAttribute(.foregroundColor, value: EditorTheme.dimmed, range: before)
        }
        if after.length > 0 {
            storage.addAttribute(.foregroundColor, value: EditorTheme.dimmed, range: after)
        }
    }

    // MARK: - Inline level

    private func styleInlineSpans(_ storage: NSTextStorage,
                                  text: NSString,
                                  protectedRanges: [NSRange],
                                  activeParagraph: NSRange?) {
        let source = storage.string
        let full = NSRange(location: 0, length: text.length)
        var claimed = protectedRanges

        // Code spans win over everything, so they are claimed first.
        for pattern in [Self.inlineCodeDouble, Self.inlineCodeSingle] {
            guard let pattern else { continue }
            pattern.enumerateMatches(in: source, range: full) { match, _, _ in
                guard let match, !self.intersects(match.range, claimed) else { return }
                storage.addAttributes([
                    .font: self.fonts.monospaced,
                    .foregroundColor: EditorTheme.codeText,
                    .backgroundColor: EditorTheme.codeBackground
                ], range: match.range)
                claimed.append(match.range)
            }
        }

        if let pattern = Self.link {
            pattern.enumerateMatches(in: source, range: full) { match, _, _ in
                guard let match, !self.intersects(match.range, claimed) else { return }
                let isActive = self.intersectsActive(match.range, activeParagraph)
                storage.addAttribute(.foregroundColor,
                                     value: self.syntaxColor(isActive: isActive),
                                     range: match.range)
                let label = match.range(at: 2)
                if label.location != NSNotFound, label.length > 0 {
                    storage.addAttribute(.foregroundColor, value: EditorTheme.text, range: label)
                }
                let target = match.range(at: 3)
                if target.location != NSNotFound, target.length > 0 {
                    storage.addAttribute(.foregroundColor, value: EditorTheme.link, range: target)
                }
                claimed.append(match.range)
            }
        }

        if let pattern = Self.autolink {
            pattern.enumerateMatches(in: source, range: full) { match, _, _ in
                guard let match, !self.intersects(match.range, claimed) else { return }
                storage.addAttribute(.foregroundColor,
                                     value: self.syntaxColor(isActive: self.intersectsActive(match.range, activeParagraph)),
                                     range: match.range)
                let target = match.range(at: 1)
                if target.location != NSNotFound {
                    storage.addAttribute(.foregroundColor, value: EditorTheme.link, range: target)
                }
                claimed.append(match.range)
            }
        }

        if let pattern = Self.bold {
            pattern.enumerateMatches(in: source, range: full) { match, _, _ in
                guard let match, !self.intersects(match.range, claimed) else { return }
                self.styleMarkers(storage, match: match, contentGroup: 2, markerGroup: 1,
                                  isActive: self.intersectsActive(match.range, activeParagraph))
                self.applyBold(storage, range: match.range(at: 2))
            }
        }

        if let pattern = Self.italic {
            pattern.enumerateMatches(in: source, range: full) { match, _, _ in
                guard let match, !self.intersects(match.range, claimed) else { return }
                self.styleMarkers(storage, match: match, contentGroup: 2, markerGroup: 1,
                                  isActive: self.intersectsActive(match.range, activeParagraph))
                self.applyItalic(storage, range: match.range(at: 2))
            }
        }

        if let pattern = Self.strikethrough {
            pattern.enumerateMatches(in: source, range: full) { match, _, _ in
                guard let match, !self.intersects(match.range, claimed) else { return }
                self.styleMarkers(storage, match: match, contentGroup: 2, markerGroup: 1,
                                  isActive: self.intersectsActive(match.range, activeParagraph))
                let content = match.range(at: 2)
                if content.location != NSNotFound {
                    storage.addAttributes([
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: EditorTheme.secondaryText
                    ], range: content)
                }
            }
        }

        if let pattern = Self.highlight {
            pattern.enumerateMatches(in: source, range: full) { match, _, _ in
                guard let match, !self.intersects(match.range, claimed) else { return }
                self.styleMarkers(storage, match: match, contentGroup: 2, markerGroup: 1,
                                  isActive: self.intersectsActive(match.range, activeParagraph))
                let content = match.range(at: 2)
                if content.location != NSNotFound {
                    storage.addAttribute(.backgroundColor, value: EditorTheme.highlightBackground, range: content)
                }
            }
        }
    }

    private func intersects(_ range: NSRange, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    /// Dims the opening and closing delimiters of an inline span.
    private func styleMarkers(_ storage: NSTextStorage,
                              match: NSTextCheckingResult,
                              contentGroup: Int,
                              markerGroup: Int,
                              isActive: Bool) {
        let marker = match.range(at: markerGroup)
        let content = match.range(at: contentGroup)
        guard marker.location != NSNotFound, content.location != NSNotFound else { return }
        let color = syntaxColor(isActive: isActive)
        storage.addAttribute(.foregroundColor, value: color, range: marker)
        let closing = NSRange(location: NSMaxRange(content), length: marker.length)
        if NSMaxRange(closing) <= storage.length {
            storage.addAttribute(.foregroundColor, value: color, range: closing)
        }
    }

    private func applyBold(_ storage: NSTextStorage, range: NSRange) {
        guard range.location != NSNotFound, range.length > 0 else { return }
        storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let current = (value as? NSFont) ?? self.fonts.regular
            let bolded = NSFontManager.shared.convert(current, toHaveTrait: .boldFontMask)
            storage.addAttribute(.font, value: bolded, range: subrange)
        }
    }

    private func applyItalic(_ storage: NSTextStorage, range: NSRange) {
        guard range.location != NSNotFound, range.length > 0 else { return }
        storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let current = (value as? NSFont) ?? self.fonts.regular
            let italic = NSFontManager.shared.convert(current, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italic, range: subrange)
            if !italic.fontDescriptor.symbolicTraits.contains(.italic) {
                storage.addAttribute(.obliqueness, value: self.fonts.syntheticObliqueness, range: subrange)
            }
        }
    }

    // MARK: - Patterns

    // Compiled once. Optional rather than force-tried: a pattern that failed to
    // build should cost one kind of highlighting, never the app.
    private static let inlineCodeDouble = try? NSRegularExpression(pattern: "``[^\\n]+?``")
    private static let inlineCodeSingle = try? NSRegularExpression(pattern: "`[^`\\n]+`")
    private static let bold = try? NSRegularExpression(pattern: "(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1")
    private static let italic = try? NSRegularExpression(
        pattern: "(?<![\\*_\\w])([\\*_])(?=[^\\s\\*_])([^\\*_]*[^\\s\\*_])\\1(?![\\*_\\w])")
    private static let strikethrough = try? NSRegularExpression(pattern: "(~~)(?=\\S)(.+?)(?<=\\S)~~")
    private static let highlight = try? NSRegularExpression(pattern: "(==)(?=\\S)(.+?)(?<=\\S)==")
    private static let link = try? NSRegularExpression(pattern: "(!?)\\[([^\\]\\n]*)\\]\\(([^)\\n]*)\\)")
    private static let autolink = try? NSRegularExpression(
        pattern: "<([a-zA-Z][a-zA-Z0-9+.-]*://[^>\\s]+)>")
}
