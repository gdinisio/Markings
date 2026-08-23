//
//  MarkdownBlock.swift
//  Markings
//

import Foundation

/// Column alignment declared by a table's delimiter row.
nonisolated enum MarkdownTableAlignment: Equatable {
    case leading
    case center
    case trailing
}

nonisolated struct MarkdownTable: Equatable {
    var alignments: [MarkdownTableAlignment]
    var header: [String]
    var rows: [[String]]
}

nonisolated struct MarkdownListItem: Identifiable {
    /// Blocks making up the item's body, so an item can hold paragraphs,
    /// nested lists, code or quotes just like any other container.
    var blocks: [MarkdownBlock]
    /// `nil` unless the item is a task item, otherwise its checked state.
    var checked: Bool?
    /// Source line carrying the item's marker, used to toggle tasks in place.
    var markerLine: Int
    /// The number shown for ordered items.
    var number: Int

    var id: Int { markerLine }
}

nonisolated struct MarkdownList {
    var isOrdered: Bool
    var isTaskList: Bool
    var items: [MarkdownListItem]
}

nonisolated enum MarkdownBlockKind {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String?, code: String)
    case blockQuote(blocks: [MarkdownBlock])
    case list(MarkdownList)
    case table(MarkdownTable)
    case thematicBreak
}

/// A parsed Markdown block, tagged with the source lines it came from.
///
/// Keeping the source range on every block is what lets the preview stay in
/// step with the caret and lets a checkbox tapped in the preview edit the exact
/// line it came from.
nonisolated struct MarkdownBlock: Identifiable {
    var kind: MarkdownBlockKind
    var firstLine: Int
    var lastLine: Int

    /// Two sibling blocks can never start on the same source line, so the first
    /// line is a stable identity for diffing and for scroll targeting.
    var id: Int { firstLine }
}
