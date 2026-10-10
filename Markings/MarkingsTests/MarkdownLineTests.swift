//
//  MarkdownLineTests.swift
//  MarkingsTests
//

import Foundation
import Testing

@Suite("Markdown line structure")
struct MarkdownLineTests {

    @Test("A line survives being parsed and composed again")
    func roundTrip() {
        let lines = [
            "Plain text",
            "# Heading",
            "###### Six",
            "- bullet",
            "* star bullet",
            "+ plus bullet",
            "  - indented bullet",
            "1. ordered",
            "12) ordered with paren",
            "- [ ] open task",
            "- [x] done task",
            "> quoted",
            "> > twice quoted",
            "    indented paragraph"
        ]
        for line in lines {
            #expect(MarkdownLine.parse(line).composed == line, "round trip failed for \(line)")
        }
    }

    @Test("Markers are split from their content")
    func markerSplitting() {
        let task = MarkdownLine.parse("  - [x] Ship it")
        #expect(task.indent == "  ")
        #expect(task.kind == .bullet(marker: "-"))
        #expect(task.task == true)
        #expect(task.content == "Ship it")

        let ordered = MarkdownLine.parse("3) Third")
        #expect(ordered.kind == .ordered(number: 3, delimiter: ")"))
        #expect(ordered.content == "Third")

        let quote = MarkdownLine.parse("> > deep")
        #expect(quote.kind == .quote(depth: 2))
        #expect(quote.content == "deep")
    }

    @Test("Things that only look like markers are left as text")
    func notMarkers() {
        // A rule, not a bullet.
        #expect(MarkdownLine.parse("***").kind == .paragraph)
        #expect(MarkdownLine.parse("---").kind == .paragraph)
        // Emphasis, not a bullet.
        #expect(MarkdownLine.parse("*emphasis*").kind == .paragraph)
        // A decimal, not an ordered item.
        #expect(MarkdownLine.parse("1.5 million").kind == .paragraph)
        // A heading needs a space after the hashes.
        #expect(MarkdownLine.parse("#hashtag").kind == .paragraph)
    }

    @Test("Content column is where nested content has to reach")
    func contentColumn() {
        #expect(MarkdownLine.parse("- item").contentColumn == 2)
        #expect(MarkdownLine.parse("1. item").contentColumn == 3)
        #expect(MarkdownLine.parse("10. item").contentColumn == 4)
        #expect(MarkdownLine.parse("- [ ] item").contentColumn == 6)
        #expect(MarkdownLine.parse("  - item").contentColumn == 4)
        #expect(MarkdownLine.parse("paragraph").contentColumn == 0)
    }

    @Test("Tabs count as four columns")
    func indentWidth() {
        #expect(MarkdownLine.indentWidth("") == 0)
        #expect(MarkdownLine.indentWidth("  ") == 2)
        #expect(MarkdownLine.indentWidth("\t") == 4)
        #expect(MarkdownLine.indentWidth("\t ") == 5)
    }

    @Test("Blank lines are recognised whatever whitespace they hold")
    func blankLines() {
        #expect(MarkdownLine.parse("").isBlank)
        #expect(MarkdownLine.parse("    ").isBlank)
        #expect(!MarkdownLine.parse("x").isBlank)
    }
}
