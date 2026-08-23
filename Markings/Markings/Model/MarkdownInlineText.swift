//
//  MarkdownInlineText.swift
//  Markings
//

import Foundation

/// Inline Markdown helpers built on Foundation's own Markdown parser.
///
/// Markings parses *block* structure itself so it can keep source line numbers,
/// but inline syntax is handed to Foundation: it is well tested, matches what
/// the rest of the platform does, and keeps emphasis, links and escapes correct
/// without another parser to maintain.
nonisolated enum MarkdownInlineText {

    static let parsingOptions = AttributedString.MarkdownParsingOptions(
        allowsExtendedAttributes: true,
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    /// Parses a single run of inline Markdown, never throwing: malformed input
    /// falls back to the literal source so the user always sees their text.
    static func attributed(_ source: String) -> AttributedString {
        (try? AttributedString(markdown: source, options: parsingOptions)) ?? AttributedString(source)
    }

    /// The text with inline syntax removed — used for outline titles, word
    /// counts and anywhere else styling would only get in the way.
    static func plainText(_ source: String) -> String {
        String(attributed(source).characters)
    }
}
