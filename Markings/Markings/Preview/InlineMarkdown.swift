//
//  InlineMarkdown.swift
//  Markings
//

import Foundation
import SwiftUI

/// Turns a run of inline Markdown into styled SwiftUI `Text`.
///
/// Foundation does the parsing; this decides what the result should look like.
/// Emphasis, code and strikethrough are resolved into explicit fonts and
/// attributes rather than left to be interpreted, so a bold word inside a
/// heading stays heading-sized and a code span inside a table cell stays the
/// size of the cell.
enum InlineMarkdown {

    static func text(_ source: String,
                     font: Font,
                     codeFont: Font,
                     accent: Color = .accentColor) -> Text {
        Text(attributed(source, font: font, codeFont: codeFont, accent: accent))
    }

    static func attributed(_ source: String,
                           font: Font,
                           codeFont: Font,
                           accent: Color = .accentColor) -> AttributedString {
        var attributed = MarkdownInlineText.attributed(source)

        // Runs cannot be mutated while they are being iterated, so the shape of
        // the string is read first and applied afterwards.
        var intents: [(Range<AttributedString.Index>, InlinePresentationIntent)] = []
        for run in attributed.runs {
            intents.append((run.range, run.inlinePresentationIntent ?? []))
        }

        attributed.font = font

        for (range, intent) in intents {
            var resolved = font
            if intent.contains(.stronglyEmphasized) { resolved = resolved.bold() }
            if intent.contains(.emphasized) { resolved = resolved.italic() }
            if intent.contains(.code) {
                resolved = codeFont
                attributed[range].backgroundColor = Color.primary.opacity(0.06)
            }
            if intent.contains(.strikethrough) {
                attributed[range].strikethroughStyle = Text.LineStyle.single
                attributed[range].foregroundColor = Color.secondary
            }
            attributed[range].font = resolved
        }

        return applyingHighlights(to: attributed)
    }

    /// `==highlight==` is a widely used extension that CommonMark does not
    /// define, so it is resolved here: the span is tinted and the markers are
    /// dropped, matching how the editor styles the same text.
    private static func applyingHighlights(to attributed: AttributedString) -> AttributedString {
        var result = attributed
        var passes = 0

        while passes < 64 {
            passes += 1
            guard let open = result.range(of: "=="), open.upperBound < result.endIndex else { break }
            guard let close = result[open.upperBound...].range(of: "==") else { break }

            var content = AttributedString(result[open.upperBound..<close.lowerBound])
            content.backgroundColor = Color.yellow.opacity(0.3)
            result.replaceSubrange(open.lowerBound..<close.upperBound, with: content)
        }
        return result
    }
}

/// Type sizes and spacing for the reading view, derived from one base size so
/// the whole hierarchy scales together.
nonisolated struct PreviewTypography: Equatable {
    var family: MarkingsFontFamily
    var baseSize: CGFloat

    var body: Font { .system(size: baseSize, design: family.fontDesign) }
    var code: Font { .system(size: baseSize * 0.88, design: .monospaced) }
    var caption: Font { .system(size: baseSize * 0.76, weight: .semibold, design: family.fontDesign) }

    var lineSpacing: CGFloat { (baseSize * 0.42).rounded() }
    var blockSpacing: CGFloat { (baseSize * 0.95).rounded() }

    func heading(_ level: Int) -> Font {
        let scales: [CGFloat] = [2.0, 1.55, 1.28, 1.12, 1.0, 0.94]
        let scale = scales[min(max(level, 1), 6) - 1]
        return .system(size: (baseSize * scale).rounded(),
                       weight: level <= 3 ? .bold : .semibold,
                       design: family.fontDesign)
    }
}

extension MarkingsFontFamily {
    nonisolated var fontDesign: Font.Design {
        switch self {
        case .sansSerif: return .default
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }
}

/// A paragraph that is nothing but one image.
///
/// Images are the one Markdown construct Markings cannot render faithfully: a
/// sandboxed app has no access to files beside the document, and fetching
/// remote images would need a network entitlement the user has not asked for.
/// Showing the reference honestly beats showing a broken image.
nonisolated struct MarkdownImageReference: Equatable {
    var alt: String
    var target: String

    var displayName: String {
        guard let last = target.split(separator: "/").last, !last.isEmpty else { return target }
        return String(last)
    }

    static func standalone(in text: String) -> MarkdownImageReference? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("!["), trimmed.hasSuffix(")") else { return nil }
        guard let labelEnd = trimmed.firstIndex(of: "]") else { return nil }
        let afterLabel = trimmed.index(after: labelEnd)
        guard afterLabel < trimmed.endIndex, trimmed[afterLabel] == "(" else { return nil }

        let alt = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<labelEnd])
        let target = String(trimmed[trimmed.index(after: afterLabel)..<trimmed.index(before: trimmed.endIndex)])
        // A second "](" means this is a line of several images, not one image.
        guard !target.contains("]("), !target.contains(")") else { return nil }
        return MarkdownImageReference(alt: alt, target: target)
    }
}
