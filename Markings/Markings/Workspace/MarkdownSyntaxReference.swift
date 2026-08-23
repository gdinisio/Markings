//
//  MarkdownSyntaxReference.swift
//  Markings
//

import Foundation
import SwiftUI

/// What the Help menu opens.
///
/// Markings ships no help book, so the stock "Markings Help" item would only
/// ever produce an error. This replaces it with the reference a Markdown app
/// should actually offer: what each piece of syntax is, how to write it, and
/// the shortcut that writes it for you.
struct MarkdownSyntaxReference: View {

    var body: some View {
        Form {
            ForEach(MarkdownSyntaxReference.sections) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        row(entry)
                    }
                }
            }

            Section {
                Text("Markings writes plain Markdown. Anything above is stored as ordinary text, so a document written here opens anywhere else — and a document written elsewhere opens here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 480, idealHeight: 620)
        .navigationTitle("Markdown Syntax")
    }

    private func row(_ entry: SyntaxEntry) -> some View {
        LabeledContent {
            HStack(spacing: 14) {
                Text(entry.syntax)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let shortcut = entry.shortcut {
                    Text(shortcut)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: 52, alignment: .trailing)
                }
            }
        } label: {
            Text(entry.name)
        }
    }
}

nonisolated struct SyntaxEntry: Identifiable {
    var name: String
    var syntax: String
    var shortcut: String?

    var id: String { name }
}

nonisolated struct SyntaxSection: Identifiable {
    var title: String
    var entries: [SyntaxEntry]

    var id: String { title }
}

extension MarkdownSyntaxReference {

    static var sections: [SyntaxSection] { [
        SyntaxSection(title: "Text", entries: [
            SyntaxEntry(name: "Bold", syntax: "**bold**", shortcut: "⌘B"),
            SyntaxEntry(name: "Italic", syntax: "*italic*", shortcut: "⌘I"),
            SyntaxEntry(name: "Strikethrough", syntax: "~~struck~~", shortcut: "⇧⌘X"),
            SyntaxEntry(name: "Inline code", syntax: "`code`", shortcut: "⌃⌘C"),
            SyntaxEntry(name: "Highlight", syntax: "==marked==", shortcut: "⌃⌘H")
        ]),
        SyntaxSection(title: "Headings", entries: [
            SyntaxEntry(name: "Heading 1", syntax: "# Title", shortcut: "⌥⌘1"),
            SyntaxEntry(name: "Heading 2", syntax: "## Section", shortcut: "⌥⌘2"),
            SyntaxEntry(name: "Heading 3", syntax: "### Subsection", shortcut: "⌥⌘3"),
            SyntaxEntry(name: "Body text", syntax: "No marker", shortcut: "⌥⌘0"),
            SyntaxEntry(name: "Raise level", syntax: "## → #", shortcut: "⌃⌘↑"),
            SyntaxEntry(name: "Lower level", syntax: "# → ##", shortcut: "⌃⌘↓")
        ]),
        SyntaxSection(title: "Lists", entries: [
            SyntaxEntry(name: "Bulleted", syntax: "- item", shortcut: "⇧⌘7"),
            SyntaxEntry(name: "Numbered", syntax: "1. item", shortcut: "⇧⌘8"),
            SyntaxEntry(name: "Task", syntax: "- [ ] to do", shortcut: "⇧⌘L"),
            SyntaxEntry(name: "Completed task", syntax: "- [x] done", shortcut: "⇧⌘D"),
            SyntaxEntry(name: "Nest an item", syntax: "Indent to the parent", shortcut: "⇥"),
            SyntaxEntry(name: "Un-nest an item", syntax: "Outdent one level", shortcut: "⇧⇥")
        ]),
        SyntaxSection(title: "Blocks", entries: [
            SyntaxEntry(name: "Block quote", syntax: "> quoted", shortcut: "⌥⌘B"),
            SyntaxEntry(name: "Code block", syntax: "```swift", shortcut: "⌥⌘C"),
            SyntaxEntry(name: "Divider", syntax: "---", shortcut: "⇧⌘-"),
            SyntaxEntry(name: "Table", syntax: "| a | b |", shortcut: "⌃⌘T")
        ]),
        SyntaxSection(title: "Links and images", entries: [
            SyntaxEntry(name: "Link", syntax: "[text](url)", shortcut: "⌘K"),
            SyntaxEntry(name: "Image", syntax: "![alt](url)", shortcut: "⌃⌘I"),
            SyntaxEntry(name: "Plain URL", syntax: "<https://…>", shortcut: nil),
            SyntaxEntry(name: "Link a selection", syntax: "Paste a URL over it", shortcut: "⌘V")
        ]),
        SyntaxSection(title: "Line breaks", entries: [
            SyntaxEntry(name: "New paragraph", syntax: "A blank line", shortcut: nil),
            SyntaxEntry(name: "Line break", syntax: "Two spaces at the end", shortcut: nil),
            SyntaxEntry(name: "Move a line", syntax: "Up or down one line", shortcut: "⌥⌘↑")
        ])
    ] }
}
