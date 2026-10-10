//
//  MarkdownTransformsTests.swift
//  MarkingsTests
//

import Foundation
import Testing

@Suite("Editing transforms")
struct MarkdownTransformsTests {

    // MARK: - Helpers

    /// Applies an edit the way the editor does and reports what the document
    /// and the selection look like afterwards.
    private func apply(_ source: String,
                       _ selection: NSRange,
                       _ transform: (NSString, NSRange) -> TextEdit?) -> (text: String, selection: NSRange)? {
        let text = source as NSString
        guard let edit = transform(text, selection) else { return nil }
        return (text.replacingCharacters(in: edit.range, with: edit.replacement), edit.selection)
    }

    private func caret(_ location: Int) -> NSRange {
        NSRange(location: location, length: 0)
    }

    private func selected(_ source: String, _ range: NSRange) -> String {
        (source as NSString).substring(with: range)
    }

    // MARK: - Inline

    @Test("Wrapping a selection, then unwrapping it, returns to where it started")
    func inlineRoundTrip() {
        guard let wrapped = apply("a word b", NSRange(location: 2, length: 4), {
            MarkdownTransforms.toggleInline(marker: "**", in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }

        #expect(wrapped.text == "a **word** b")
        #expect(selected(wrapped.text, wrapped.selection) == "word",
                "the same word stays selected so a second command hits it")

        guard let unwrapped = apply(wrapped.text, wrapped.selection, {
            MarkdownTransforms.toggleInline(marker: "**", in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }

        #expect(unwrapped.text == "a word b")
        #expect(selected(unwrapped.text, unwrapped.selection) == "word")
    }

    @Test("Markers inside the selection are recognised too")
    func unwrapFromInside() {
        guard let result = apply("**word**", NSRange(location: 0, length: 8), {
            MarkdownTransforms.toggleInline(marker: "**", in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "word")
    }

    @Test("A caret inside a word wraps the whole word")
    func caretExpandsToWord() {
        guard let result = apply("hello", caret(2), {
            MarkdownTransforms.toggleInline(marker: "*", in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "*hello*")
        #expect(selected(result.text, result.selection) == "hello")
    }

    @Test("A caret in empty space leaves the markers ready to type between")
    func caretInEmptySpace() {
        guard let result = apply("", caret(0), {
            MarkdownTransforms.toggleInline(marker: "**", in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "****")
        #expect(result.selection == NSRange(location: 2, length: 0))
    }

    @Test("Trailing whitespace is left outside the markers")
    func trailingSpaceExcluded() {
        guard let result = apply("word ", NSRange(location: 0, length: 5), {
            MarkdownTransforms.toggleInline(marker: "**", in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "**word** ", "“**word **” is not emphasis in any Markdown dialect")
    }

    // MARK: - Headings and paragraph styles

    @Test("Setting a heading level, and setting it again, toggles it off")
    func headingToggle() {
        guard let on = apply("Title", caret(0), {
            MarkdownTransforms.setHeading(level: 2, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(on.text == "## Title")

        guard let off = apply(on.text, caret(3), {
            MarkdownTransforms.setHeading(level: 2, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(off.text == "Title")
    }

    @Test("A different level replaces rather than stacks")
    func headingReplace() {
        guard let result = apply("## Two", caret(3), {
            MarkdownTransforms.setHeading(level: 1, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "# Two")
    }

    @Test("Body strips whatever marker the line had")
    func setBody() {
        for source in ["# Heading", "- bullet", "1. ordered", "> quoted", "- [x] task"] {
            guard let result = apply(source, caret(source.utf16.count), {
                MarkdownTransforms.setBody(in: $0, selection: $1)
            }) else { Issue.record("no edit for \(source)"); return }
            #expect(!result.text.contains("#"))
            #expect(!result.text.hasPrefix("-"))
            #expect(!result.text.hasPrefix(">"))
        }
    }

    // MARK: - Lists

    @Test("Bulleting a block of lines, then unbulleting it, round-trips")
    func bulletToggle() {
        let source = "one\ntwo\nthree"
        guard let on = apply(source, NSRange(location: 0, length: source.utf16.count), {
            MarkdownTransforms.toggleBulletList(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(on.text == "- one\n- two\n- three")

        guard let off = apply(on.text, on.selection, {
            MarkdownTransforms.toggleBulletList(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(off.text == source)
    }

    @Test("Numbering counts from one, in order")
    func numberedList() {
        let source = "one\ntwo\nthree"
        guard let result = apply(source, NSRange(location: 0, length: source.utf16.count), {
            MarkdownTransforms.toggleNumberedList(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "1. one\n2. two\n3. three")
    }

    @Test("Blank lines inside a selection stay blank")
    func blankLinesUntouched() {
        guard let result = apply("one\n\ntwo", NSRange(location: 0, length: 8), {
            MarkdownTransforms.toggleBulletList(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "- one\n\n- two")
    }

    @Test("Task lists add a checkbox to a plain line and to an existing bullet")
    func taskList() {
        guard let plain = apply("thing", caret(0), {
            MarkdownTransforms.toggleTaskList(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(plain.text == "- [ ] thing")

        guard let bullet = apply("- thing", caret(0), {
            MarkdownTransforms.toggleTaskList(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(bullet.text == "- [ ] thing")
    }

    @Test("Completion flips, and flips back")
    func taskCompletion() {
        guard let done = apply("- [ ] thing", caret(7), {
            MarkdownTransforms.toggleTaskCompletion(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(done.text == "- [x] thing")

        guard let undone = apply(done.text, caret(7), {
            MarkdownTransforms.toggleTaskCompletion(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(undone.text == "- [ ] thing")
    }

    @Test("Toggling completion on a line with no task does nothing at all")
    func taskCompletionNoop() {
        let result = apply("just text", caret(0), {
            MarkdownTransforms.toggleTaskCompletion(in: $0, selection: $1)
        })
        #expect(result == nil, "an undo step for a no-op is worse than no command")
    }

    @Test("A task can be flipped by source line, the way the preview does it")
    func toggleTaskByLine() {
        let source = "# Title\n\n- [ ] one\n- [x] two"
        #expect(MarkdownTransforms.toggleTask(atLine: 2, in: source) == "# Title\n\n- [x] one\n- [x] two")
        #expect(MarkdownTransforms.toggleTask(atLine: 3, in: source) == "# Title\n\n- [ ] one\n- [ ] two")
        #expect(MarkdownTransforms.toggleTask(atLine: 0, in: source) == nil)
        #expect(MarkdownTransforms.toggleTask(atLine: 99, in: source) == nil)
    }

    // MARK: - Quotes

    @Test("Quoting keeps whatever the line already was")
    func quotePreservesStructure() {
        guard let result = apply("- item", caret(0), {
            MarkdownTransforms.toggleBlockQuote(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "> - item", "quoting a list item should still be a list item")

        guard let off = apply(result.text, caret(0), {
            MarkdownTransforms.toggleBlockQuote(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(off.text == "- item")
    }

    // MARK: - Indentation

    @Test("Indenting lines up with the parent item's content column")
    func indentAlignsToParent() {
        guard let bullet = apply("- one\n- two", caret(6), {
            MarkdownTransforms.indent(in: $0, selection: $1, tabWidth: 2)
        }) else { Issue.record("no edit"); return }
        #expect(bullet.text == "- one\n  - two", "a bullet's content starts at column 2")

        guard let ordered = apply("1. one\n1. two", caret(7), {
            MarkdownTransforms.indent(in: $0, selection: $1, tabWidth: 2)
        }) else { Issue.record("no edit"); return }
        #expect(ordered.text == "1. one\n   1. two",
                "an ordered item's content starts at column 3, so two spaces would not nest")
    }

    @Test("Outdenting returns to the enclosing item's own column")
    func outdentAlignsToAncestor() {
        guard let result = apply("- one\n  - two", caret(8), {
            MarkdownTransforms.outdent(in: $0, selection: $1, tabWidth: 2)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "- one\n- two")

        guard let deep = apply("- a\n  - b\n    - c", caret(14), {
            MarkdownTransforms.outdent(in: $0, selection: $1, tabWidth: 2)
        }) else { Issue.record("no edit"); return }
        #expect(deep.text == "- a\n  - b\n  - c")
    }

    @Test("There is nothing to outdent at column zero")
    func outdentFloor() {
        #expect(apply("- one", caret(2), {
            MarkdownTransforms.outdent(in: $0, selection: $1, tabWidth: 2)
        }) == nil)
    }

    // MARK: - Return key

    @Test("Return continues a list item")
    func continueBullet() {
        guard let result = apply("- item", caret(6), {
            MarkdownTransforms.newlineContinuation(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "- item\n- ")
        #expect(result.selection == caret(9))
    }

    @Test("Return numbers the next ordered item")
    func continueOrdered() {
        guard let result = apply("1. one", caret(6), {
            MarkdownTransforms.newlineContinuation(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "1. one\n2. ")
    }

    @Test("Return on a task item starts an unchecked one")
    func continueTask() {
        guard let result = apply("- [x] done", caret(10), {
            MarkdownTransforms.newlineContinuation(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "- [x] done\n- [ ] ", "the next thing to do is not already done")
    }

    @Test("Return continues a quote, and keeps its depth")
    func continueQuote() {
        guard let result = apply("> > deep", caret(8), {
            MarkdownTransforms.newlineContinuation(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "> > deep\n> > ")
    }

    @Test("Return on an empty item ends the list instead of adding another")
    func endListOnEmptyItem() {
        guard let result = apply("- one\n- ", caret(8), {
            MarkdownTransforms.newlineContinuation(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "- one\n")
        #expect(result.selection == caret(6))
    }

    @Test("Return keeps the indentation of an indented plain line")
    func continueIndent() {
        guard let result = apply("    indented", caret(12), {
            MarkdownTransforms.newlineContinuation(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "    indented\n    ")
    }

    @Test("Return before the marker is an ordinary Return")
    func noContinuationInsideMarker() {
        #expect(apply("- item", caret(0), {
            MarkdownTransforms.newlineContinuation(in: $0, selection: $1)
        }) == nil, "otherwise the marker would be pushed onto its own line")
    }

    @Test("Return on a plain unindented line is an ordinary Return")
    func noContinuationOnPlainLine() {
        #expect(apply("text", caret(4), {
            MarkdownTransforms.newlineContinuation(in: $0, selection: $1)
        }) == nil)
    }

    // MARK: - Moving lines

    @Test("A line swaps with the one above or below, and the caret follows it")
    func moveLines() {
        guard let up = apply("a\nb\nc", caret(2), {
            MarkdownTransforms.moveLines(by: -1, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(up.text == "b\na\nc")
        #expect(up.selection == caret(0), "the caret stays on the line it moved")

        guard let down = apply("a\nb\nc", caret(0), {
            MarkdownTransforms.moveLines(by: 1, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(down.text == "b\na\nc")
        #expect(down.selection == caret(2))
    }

    @Test("There is nowhere to move at the ends of the document")
    func moveLinesAtBoundaries() {
        #expect(apply("a\nb", caret(0), {
            MarkdownTransforms.moveLines(by: -1, in: $0, selection: $1)
        }) == nil)
        #expect(apply("a\nb", caret(2), {
            MarkdownTransforms.moveLines(by: 1, in: $0, selection: $1)
        }) == nil)
        #expect(apply("only", caret(0), {
            MarkdownTransforms.moveLines(by: 1, in: $0, selection: $1)
        }) == nil)
    }

    // MARK: - Heading level

    @Test("Raising and lowering walks the heading scale and stops at both ends")
    func headingLevelScale() {
        guard let raised = apply("## Two", caret(4), {
            MarkdownTransforms.changeHeadingLevel(by: -1, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(raised.text == "# Two")

        #expect(apply("# One", caret(3), {
            MarkdownTransforms.changeHeadingLevel(by: -1, in: $0, selection: $1)
        }) == nil, "there is nothing above Heading 1")

        guard let promoted = apply("Body", caret(0), {
            MarkdownTransforms.changeHeadingLevel(by: -1, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(promoted.text == "# Body", "raising body text makes it a heading")

        guard let demoted = apply("###### Six", caret(8), {
            MarkdownTransforms.changeHeadingLevel(by: 1, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(demoted.text == "Six", "below Heading 6 is body text")

        #expect(apply("- item", caret(3), {
            MarkdownTransforms.changeHeadingLevel(by: 1, in: $0, selection: $1)
        }) == nil, "a list item is not on the heading scale")
    }

    // MARK: - Insertions

    @Test("A link wraps the selection and offers the URL for typing")
    func insertLink() {
        guard let result = apply("text", NSRange(location: 0, length: 4), {
            MarkdownTransforms.insertLink(isImage: false, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "[text](https://)")
        #expect(selected(result.text, result.selection) == "https://",
                "the placeholder is selected so a paste replaces it")
    }

    @Test("A selected URL becomes the target, not the label")
    func insertLinkFromURL() {
        guard let result = apply("https://example.com", NSRange(location: 0, length: 19), {
            MarkdownTransforms.insertLink(isImage: false, in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "[](https://example.com)")
        #expect(result.selection == caret(1), "the caret lands where the label goes")
    }

    @Test("A code block is separated from the paragraph above it")
    func insertCodeBlock() {
        guard let result = apply("Hello", caret(5), {
            MarkdownTransforms.insertCodeBlock(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "Hello\n\n```\n\n```", "a fence glued to a paragraph is not a fence")
        #expect(result.selection == caret(11), "the caret starts between the fences")
    }

    @Test("A block inserted on a blank line reuses that line")
    func insertOnBlankLine() {
        guard let result = apply("", caret(0), {
            MarkdownTransforms.insertThematicBreak(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text == "---")
    }

    @Test("A table arrives with its first heading selected")
    func insertTable() {
        guard let result = apply("", caret(0), {
            MarkdownTransforms.insertTable(in: $0, selection: $1)
        }) else { Issue.record("no edit"); return }
        #expect(result.text.hasPrefix("| Column 1 | Column 2 | Column 3 |"))
        #expect(selected(result.text, result.selection) == "Column 1")
    }

    // MARK: - Geometry

    @Test("Line and column counting")
    func lineGeometry() {
        let text = "a\nbb\nc" as NSString
        #expect(MarkdownTransforms.lineNumber(in: text, at: 0) == 0)
        #expect(MarkdownTransforms.lineNumber(in: text, at: 2) == 1)
        #expect(MarkdownTransforms.lineNumber(in: text, at: 5) == 2)
        #expect(MarkdownTransforms.column(in: text, at: 0) == 1)
        #expect(MarkdownTransforms.column(in: text, at: 3) == 2)
    }

    @Test("A line number resolves to the right range, and an impossible one to nothing")
    func rangeOfLine() {
        let text = "a\nbb\nc" as NSString
        #expect(MarkdownTransforms.range(ofLine: 0, in: text) == NSRange(location: 0, length: 1))
        #expect(MarkdownTransforms.range(ofLine: 1, in: text) == NSRange(location: 2, length: 2))
        #expect(MarkdownTransforms.range(ofLine: 2, in: text) == NSRange(location: 5, length: 1))
        #expect(MarkdownTransforms.range(ofLine: 9, in: text) == nil)
    }

    @Test("A selection ending on a line break does not drag the next line in")
    func lineRangeStopsAtBreak() {
        let text = "one\ntwo" as NSString
        let range = MarkdownTransforms.lineRange(in: text, for: NSRange(location: 0, length: 4))
        #expect(range == NSRange(location: 0, length: 3))
    }

    @Test("The paragraph style of the caret's line is reported")
    func blockStyleDetection() {
        #expect(MarkdownTransforms.blockStyle(in: "text" as NSString, at: caret(0)) == .body)
        #expect(MarkdownTransforms.blockStyle(in: "### x" as NSString, at: caret(0)) == .heading(3))
        #expect(MarkdownTransforms.blockStyle(in: "- x" as NSString, at: caret(0)) == .bulletList)
        #expect(MarkdownTransforms.blockStyle(in: "1. x" as NSString, at: caret(0)) == .numberedList)
        #expect(MarkdownTransforms.blockStyle(in: "- [ ] x" as NSString, at: caret(0)) == .taskList)
        #expect(MarkdownTransforms.blockStyle(in: "> x" as NSString, at: caret(0)) == .quote)
    }

    @Test("Only something that could be a URL is treated as one")
    func urlDetection() {
        #expect(MarkdownTransforms.looksLikeURL("https://example.com"))
        #expect(MarkdownTransforms.looksLikeURL("mailto:a@b.c"))
        #expect(MarkdownTransforms.looksLikeURL("www.example.com"))
        #expect(!MarkdownTransforms.looksLikeURL("just text"))
        #expect(!MarkdownTransforms.looksLikeURL("https://a b"))
        #expect(!MarkdownTransforms.looksLikeURL(""))
    }
}
