//
//  MarkdownParserTests.swift
//  MarkingsTests
//

import Foundation
import Testing

@Suite("Block parsing")
struct MarkdownParserTests {

    // MARK: - Helpers

    private func blocks(_ source: String) -> [MarkdownBlock] {
        MarkdownParser.parse(source)
    }

    private func firstKind(_ source: String) -> MarkdownBlockKind? {
        blocks(source).first?.kind
    }

    // MARK: - Headings

    @Test("ATX headings, including a closing run of hashes")
    func atxHeadings() {
        guard case .heading(let level, let text)? = firstKind("## Section") else {
            Issue.record("expected a heading"); return
        }
        #expect(level == 2)
        #expect(text == "Section")

        guard case .heading(_, let closed)? = firstKind("### Title ###") else {
            Issue.record("expected a heading"); return
        }
        #expect(closed == "Title", "a closing hash run is decoration, not content")
    }

    @Test("Setext headings win over a thematic break")
    func setextHeadings() {
        let underlined = blocks("Title\n=====")
        guard case .heading(let level, let text)? = underlined.first?.kind else {
            Issue.record("expected a heading"); return
        }
        #expect(level == 1)
        #expect(text == "Title")
        #expect(underlined.first?.lastLine == 1, "the heading covers both its lines")

        guard case .heading(let second, _)? = blocks("Title\n---").first?.kind else {
            Issue.record("expected a level 2 heading, not a thematic break"); return
        }
        #expect(second == 2)
    }

    @Test("A rule on its own is a thematic break")
    func thematicBreak() {
        for rule in ["---", "***", "___", "- - -", "*****"] {
            if case .thematicBreak? = firstKind(rule) { continue }
            Issue.record("\(rule) should be a thematic break")
        }
        // Two dashes is not enough.
        if case .thematicBreak? = firstKind("--") {
            Issue.record("-- is not a thematic break")
        }
    }

    // MARK: - Paragraphs

    @Test("Soft line breaks join, hard line breaks do not")
    func paragraphJoining() {
        guard case .paragraph(let joined)? = firstKind("one\ntwo") else {
            Issue.record("expected a paragraph"); return
        }
        #expect(joined == "one two")

        guard case .paragraph(let hard)? = firstKind("one  \ntwo") else {
            Issue.record("expected a paragraph"); return
        }
        #expect(hard == "one\ntwo", "two trailing spaces are a hard break")

        guard case .paragraph(let backslash)? = firstKind("one\\\ntwo") else {
            Issue.record("expected a paragraph"); return
        }
        #expect(backslash == "one\ntwo", "a trailing backslash is a hard break")
    }

    @Test("A blank line separates paragraphs")
    func paragraphSeparation() {
        let parsed = blocks("one\n\ntwo")
        #expect(parsed.count == 2)
        #expect(parsed.last?.firstLine == 2)
    }

    // MARK: - Code

    @Test("Fenced code keeps its language and its contents verbatim")
    func fencedCode() {
        guard case .codeBlock(let language, let code)? = firstKind("```swift\nlet x = 1\n```") else {
            Issue.record("expected a code block"); return
        }
        #expect(language == "swift")
        #expect(code == "let x = 1")

        // Markdown inside a fence is still code.
        guard case .codeBlock(_, let literal)? = firstKind("```\n# not a heading\n```") else {
            Issue.record("expected a code block"); return
        }
        #expect(literal == "# not a heading")
    }

    @Test("An unterminated fence runs to the end rather than swallowing the parser")
    func unterminatedFence() {
        let parsed = blocks("```\nstill code\nand more")
        #expect(parsed.count == 1)
        guard case .codeBlock(_, let code)? = parsed.first?.kind else {
            Issue.record("expected a code block"); return
        }
        #expect(code == "still code\nand more")
    }

    @Test("Tildes fence as well as backticks, and do not close each other")
    func tildeFence() {
        guard case .codeBlock(_, let code)? = firstKind("~~~\n```\n~~~") else {
            Issue.record("expected a code block"); return
        }
        #expect(code == "```")
    }

    // MARK: - Quotes

    @Test("Block quotes nest")
    func nestedQuotes() {
        guard case .blockQuote(let inner)? = firstKind("> outer\n> > inner") else {
            Issue.record("expected a block quote"); return
        }
        #expect(inner.count == 2)
        guard case .paragraph(let text)? = inner.first?.kind else {
            Issue.record("expected a paragraph first"); return
        }
        #expect(text == "outer")
        guard case .blockQuote? = inner.last?.kind else {
            Issue.record("expected a nested quote"); return
        }
    }

    // MARK: - Lists

    @Test("A list collects its items and records each marker's line")
    func listItems() {
        guard case .list(let list)? = firstKind("- one\n- two\n- three") else {
            Issue.record("expected a list"); return
        }
        #expect(list.items.count == 3)
        #expect(!list.isOrdered)
        #expect(list.items.map(\.markerLine) == [0, 1, 2])
    }

    @Test("Nested list items become blocks inside their parent item")
    func nestedList() {
        guard case .list(let list)? = firstKind("- one\n- two\n  - nested") else {
            Issue.record("expected a list"); return
        }
        #expect(list.items.count == 2)
        let second = list.items[1]
        #expect(second.blocks.count == 2, "a paragraph and the nested list")
        guard case .list(let nested)? = second.blocks.last?.kind else {
            Issue.record("expected a nested list"); return
        }
        #expect(nested.items.count == 1)
        #expect(nested.items[0].markerLine == 2, "nesting must not lose the source line")
    }

    @Test("Ordered lists keep their own numbers")
    func orderedList() {
        guard case .list(let list)? = firstKind("3. three\n4. four") else {
            Issue.record("expected a list"); return
        }
        #expect(list.isOrdered)
        #expect(list.items.map(\.number) == [3, 4])
    }

    @Test("Task items carry their checked state")
    func taskList() {
        guard case .list(let list)? = firstKind("- [ ] open\n- [x] done") else {
            Issue.record("expected a list"); return
        }
        #expect(list.isTaskList)
        let checked: [Bool?] = list.items.map(\.checked)
        #expect(checked == [false, true])
    }

    @Test("A blank line between items keeps them in one list")
    func looseList() {
        guard case .list(let list)? = firstKind("- one\n\n- two") else {
            Issue.record("expected one list, not two"); return
        }
        #expect(list.items.count == 2)
    }

    @Test("An ordered list does not absorb a bulleted one")
    func listTypeBoundary() {
        let parsed = blocks("1. ordered\n- bulleted")
        #expect(parsed.count == 2, "different markers are different lists")
    }

    // MARK: - Tables

    @Test("Tables read their header, alignment and rows")
    func table() {
        guard case .table(let table)? = firstKind("| a | b | c |\n| :-- | :-: | --: |\n| 1 | 2 | 3 |") else {
            Issue.record("expected a table"); return
        }
        #expect(table.header == ["a", "b", "c"])
        #expect(table.alignments == [.leading, .center, .trailing])
        #expect(table.rows == [["1", "2", "3"]])
    }

    @Test("A ragged row is padded rather than dropped")
    func raggedTable() {
        guard case .table(let table)? = firstKind("| a | b |\n| --- | --- |\n| 1 |") else {
            Issue.record("expected a table"); return
        }
        #expect(table.rows == [["1", ""]])
    }

    @Test("A paragraph above a rule is a heading, not a one-column table")
    func notATable() {
        if case .table? = firstKind("Title\n---") {
            Issue.record("a setext heading was parsed as a table")
        }
    }

    // MARK: - Source mapping

    @Test("Every block points back at the lines it came from")
    func sourceLines() {
        let source = """
            # Title

            A paragraph.

            - one
            - two

            ## Next
            """
        let parsed = blocks(source)
        #expect(parsed.count == 4)
        #expect(parsed[0].firstLine == 0)
        #expect(parsed[1].firstLine == 2)
        #expect(parsed[2].firstLine == 4)
        #expect(parsed[2].lastLine == 5)
        #expect(parsed[3].firstLine == 7)
    }

    @Test("Sibling blocks never share an identity")
    func uniqueIdentities() {
        let source = """
            # One
            Text
            - a
            - b

            > quote

            ```
            code
            ```

            | h |
            | - |
            | c |

            ---
            """
        let identities = blocks(source).map(\.id)
        #expect(Set(identities).count == identities.count,
                "the preview uses these as view identities and scroll targets")
    }

    // MARK: - Robustness

    @Test("Awkward input terminates and produces something")
    func doesNotHang() {
        let awkward = [
            "", "\n", "\n\n\n", "   ", "#", "#######", ">", "> >", "-", "- ",
            "1.", "|", "||", "| |", "```", "~~~", "---\n---\n---",
            "- \n- \n- ", "> \n> \n> ", String(repeating: "- a\n", count: 200),
            String(repeating: "#", count: 50) + " deep",
            String(repeating: " ", count: 40) + "- buried"
        ]
        for source in awkward {
            _ = MarkdownParser.parse(source)
        }
    }
}
