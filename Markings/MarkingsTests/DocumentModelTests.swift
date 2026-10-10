//
//  DocumentModelTests.swift
//  MarkingsTests
//

import Foundation
import Testing

@Suite("Outline")
struct DocumentOutlineTests {

    private let source = """
        # Guide
        ## Setup
        ### Requirements
        ## Usage
        Text
        """

    private var items: [OutlineItem] {
        DocumentOutline.items(from: MarkdownParser.parse(source))
    }

    @Test("Only headings, in order, with their source lines")
    func headings() {
        #expect(items.map(\.title) == ["Guide", "Setup", "Requirements", "Usage"])
        #expect(items.map(\.level) == [1, 2, 3, 2])
        #expect(items.map(\.line) == [0, 1, 2, 3])
    }

    @Test("Inline syntax is stripped from a heading's title")
    func titlesAreProse() {
        let styled = DocumentOutline.items(from: MarkdownParser.parse("# A **bold** `title`"))
        #expect(styled.first?.title == "A bold title", "a sidebar should read as prose, not as source")
    }

    @Test("An empty heading still gets a name")
    func emptyHeading() {
        let empty = DocumentOutline.items(from: MarkdownParser.parse("#"))
        #expect(empty.first?.title == "Untitled heading")
    }

    @Test("The caret's section is the nearest heading at or above it")
    func containingSection() {
        #expect(DocumentOutline.item(containing: 2, in: items)?.title == "Requirements")
        #expect(DocumentOutline.item(containing: 4, in: items)?.title == "Usage")
        #expect(DocumentOutline.item(containing: 0, in: items)?.title == "Guide")
    }

    @Test("The heading path climbs to the top of the document")
    func headingPath() {
        #expect(DocumentOutline.path(to: 2, in: items).map(\.title) == ["Guide", "Setup", "Requirements"])
        #expect(DocumentOutline.path(to: 3, in: items).map(\.title) == ["Guide", "Usage"],
                "a sibling section is not an ancestor")
        #expect(DocumentOutline.path(to: 0, in: items).map(\.title) == ["Guide"])
        #expect(DocumentOutline.path(to: 0, in: []).isEmpty)
    }
}

@Suite("Statistics")
struct DocumentStatisticsTests {

    private func statistics(_ source: String) -> DocumentStatistics {
        DocumentStatistics.make(source: source, blocks: MarkdownParser.parse(source))
    }

    @Test("Words come from the prose, not the punctuation")
    func wordCount() {
        #expect(statistics("# Title\n\nHello world.").words == 3)
        #expect(statistics("**bold** *italic*").words == 2, "markers are not words")
        #expect(statistics("[label](https://example.com)").words == 1,
                "a link target is not words the reader sees")
        #expect(statistics("").words == 0)
    }

    @Test("Code blocks are not counted as prose")
    func codeExcluded() {
        let stats = statistics("Text here\n\n```\nlet a = 1\nlet b = 2\n```")
        #expect(stats.words == 2)
        #expect(stats.codeBlocks == 1)
    }

    @Test("Structure is counted")
    func structure() {
        let stats = statistics("""
            # One
            ## Two

            A paragraph.

            - [x] done
            - [ ] todo

            | a | b |
            | - | - |
            | 1 | 2 |

            ![alt](pic.png) and [link](x)
            """)
        #expect(stats.headings == 2)
        #expect(stats.tables == 1)
        #expect(stats.tasksTotal == 2)
        #expect(stats.tasksCompleted == 1)
        #expect(stats.images == 1)
        #expect(stats.links == 1, "an image is not also a link")
    }

    @Test("Reading time is never zero")
    func readingTime() {
        #expect(statistics("").readingMinutes == 1)
        #expect(statistics("word").readingMinutes == 1)
    }

    @Test("Task progress is a fraction, and safe when there are no tasks")
    func taskProgress() {
        #expect(statistics("- [x] a\n- [ ] b").taskCompletion == 0.5)
        #expect(statistics("no tasks").taskCompletion == 0)
        #expect(!statistics("no tasks").hasTasks)
    }
}

@Suite("Plain text")
struct MarkdownPlainTextTests {

    private func render(_ source: String) -> String {
        MarkdownPlainText.render(MarkdownParser.parse(source))
    }

    @Test("Syntax goes, structure stays")
    func structureSurvives() {
        let result = render("# Title\n\n- one\n- two")
        #expect(result.contains("Title"))
        #expect(!result.contains("#"))
        #expect(result.contains("• one"))
        #expect(result.contains("• two"))
    }

    @Test("Numbering and checkboxes become characters a reader understands")
    func markers() {
        #expect(render("1. first\n2. second").contains("1. first"))
        let tasks = render("- [x] done\n- [ ] todo")
        #expect(tasks.contains("☑ done"))
        #expect(tasks.contains("☐ todo"))
    }

    @Test("Table rows are tab separated, so they paste into a spreadsheet")
    func tables() {
        let result = render("| a | b |\n| - | - |\n| 1 | 2 |")
        #expect(result.contains("a\tb"))
        #expect(result.contains("1\t2"))
    }

    @Test("Emphasis is removed from the words it was marking")
    func inlineStripped() {
        #expect(render("Some **bold** text") == "Some bold text")
    }
}

@Suite("HTML export")
struct MarkdownHTMLExporterTests {

    private func body(_ source: String) -> String {
        MarkdownHTMLExporter.body(blocks: MarkdownParser.parse(source))
    }

    @Test("Blocks become the elements they describe")
    func elements() {
        #expect(body("# Title").contains("<h1>Title</h1>"))
        #expect(body("###### Six").contains("<h6>"))
        #expect(body("Text").contains("<p>Text</p>"))
        #expect(body("---").contains("<hr>"))
        #expect(body("> quoted").contains("<blockquote>"))
        #expect(body("- one").contains("<ul>"))
        #expect(body("1. one").contains("<ol>"))
        #expect(body("| a |\n| - |\n| 1 |").contains("<table>"))
    }

    @Test("Inline emphasis becomes inline elements")
    func inlineElements() {
        #expect(body("**bold**").contains("<strong>bold</strong>"))
        #expect(body("*italic*").contains("<em>italic</em>"))
        #expect(body("`code`").contains("<code>code</code>"))
        #expect(body("~~struck~~").contains("<del>struck</del>"))
        #expect(body("==marked==").contains("<mark>marked</mark>"))
        #expect(body("[label](https://example.com)")
            .contains("<a href=\"https://example.com\">label</a>"))
    }

    @Test("A code block's language is carried on the element")
    func codeLanguage() {
        #expect(body("```swift\nlet x = 1\n```").contains("class=\"language-swift\""))
    }

    @Test("Document text can never become markup")
    func escaping() {
        // The whole point: a document is text, and must arrive in the export as text.
        let exported = body("A <script>alert('x')</script> & B")
        #expect(!exported.contains("<script>"))
        #expect(exported.contains("&lt;script&gt;"))
        #expect(exported.contains("&amp;"))

        let code = body("```\n<b>not bold</b>\n```")
        #expect(!code.contains("<b>"))
        #expect(code.contains("&lt;b&gt;"))
    }

    @Test("A quote mark in a link target cannot break out of the attribute")
    func attributeEscaping() {
        let exported = body("[x](https://example.com/\"onmouseover=\"alert(1))")
        #expect(!exported.contains("\"onmouseover=\""))
    }

    @Test("A whole document comes out as one file with its title")
    func wholeDocument() {
        let html = MarkdownHTMLExporter.document(title: "My Notes",
                                                 blocks: MarkdownParser.parse("# Hello"))
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("<title>My Notes</title>"))
        #expect(html.contains("prefers-color-scheme"), "the export should follow the reader's appearance")
        #expect(html.contains("</html>"))
    }
}

@Suite("Document file")
struct MarkingsDocumentTests {

    @Test("Line endings are normalised on the way in")
    func lineEndings() {
        #expect(MarkingsDocument.normalizingLineEndings("a\r\nb") == "a\nb")
        #expect(MarkingsDocument.normalizingLineEndings("a\rb") == "a\nb")
        #expect(MarkingsDocument.normalizingLineEndings("a\nb") == "a\nb")
        #expect(MarkingsDocument.normalizingLineEndings("a\r\n\rb") == "a\n\nb")
    }

    @Test("A new document is empty")
    func newDocument() {
        #expect(MarkingsDocument().text.isEmpty, "a blank page is faster than one to delete")
    }
}
