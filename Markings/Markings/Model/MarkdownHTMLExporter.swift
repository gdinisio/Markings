//
//  MarkdownHTMLExporter.swift
//  Markings
//

import Foundation

/// Renders a parsed document as a single self-contained HTML file.
///
/// The stylesheet deliberately mirrors the in-app reading view — system fonts,
/// a comfortable measure, light and dark support — so an exported file looks
/// like the document the user was just reading rather than a browser default.
nonisolated enum MarkdownHTMLExporter {

    static func document(title: String, blocks: [MarkdownBlock]) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        \(stylesheet)
        </style>
        </head>
        <body>
        <main>
        \(body(blocks: blocks))
        </main>
        </body>
        </html>
        """
    }

    static func body(blocks: [MarkdownBlock], indent: String = "") -> String {
        blocks.map { block in indent + html(for: block, indent: indent) }.joined(separator: "\n")
    }

    private static func html(for block: MarkdownBlock, indent: String) -> String {
        switch block.kind {
        case .heading(let level, let text):
            let tag = "h\(min(max(level, 1), 6))"
            return "<\(tag)>\(inline(text))</\(tag)>"

        case .paragraph(let text):
            return "<p>\(inline(text))</p>"

        case .thematicBreak:
            return "<hr>"

        case .codeBlock(let language, let code):
            let attribute = language.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
            return "<pre><code\(attribute)>\(escape(code))</code></pre>"

        case .blockQuote(let inner):
            return "<blockquote>\n\(body(blocks: inner, indent: indent + "  "))\n\(indent)</blockquote>"

        case .list(let list):
            let tag = list.isOrdered ? "ol" : "ul"
            let attribute = list.isTaskList ? " class=\"task-list\"" : ""
            let items = list.items.map { item -> String in
                let marker: String
                switch item.checked {
                case .some(true): marker = "<input type=\"checkbox\" checked disabled> "
                case .some(false): marker = "<input type=\"checkbox\" disabled> "
                case .none: marker = ""
                }
                return "\(indent)  <li>\(marker)\(inlineItemBody(item, indent: indent))</li>"
            }
            return "<\(tag)\(attribute)>\n\(items.joined(separator: "\n"))\n\(indent)</\(tag)>"

        case .table(let table):
            return tableHTML(for: table, indent: indent)
        }
    }

    /// A list item whose only content is one paragraph reads better without the
    /// `<p>` wrapper, which is what browsers expect from a tight list.
    private static func inlineItemBody(_ item: MarkdownListItem, indent: String) -> String {
        if item.blocks.count == 1, case .paragraph(let text) = item.blocks[0].kind {
            return inline(text)
        }
        return "\n" + body(blocks: item.blocks, indent: indent + "    ") + "\n\(indent)  "
    }

    private static func tableHTML(for table: MarkdownTable, indent: String) -> String {
        func cells(_ values: [String], tag: String) -> String {
            values.enumerated().map { column, value in
                let alignment = column < table.alignments.count ? table.alignments[column] : .leading
                let style: String
                switch alignment {
                case .leading: style = ""
                case .center: style = " style=\"text-align:center\""
                case .trailing: style = " style=\"text-align:right\""
                }
                return "<\(tag)\(style)>\(inline(value))</\(tag)>"
            }.joined()
        }

        let header = "\(indent)  <thead><tr>\(cells(table.header, tag: "th"))</tr></thead>"
        let rows = table.rows.map { "\(indent)    <tr>\(cells($0, tag: "td"))</tr>" }.joined(separator: "\n")
        return "<table>\n\(header)\n\(indent)  <tbody>\n\(rows)\n\(indent)  </tbody>\n\(indent)</table>"
    }

    // MARK: - Inline

    static func inline(_ source: String) -> String {
        let attributed = MarkdownInlineText.attributed(source)
        var html = ""

        for run in attributed.runs {
            var fragment = escape(String(attributed[run.range].characters))
            fragment = fragment.replacingOccurrences(of: "\n", with: "<br>\n")

            let intent = run.inlinePresentationIntent ?? []
            if intent.contains(.code) { fragment = "<code>\(fragment)</code>" }
            if intent.contains(.strikethrough) { fragment = "<del>\(fragment)</del>" }
            if intent.contains(.emphasized) { fragment = "<em>\(fragment)</em>" }
            if intent.contains(.stronglyEmphasized) { fragment = "<strong>\(fragment)</strong>" }
            if let link = run.link {
                fragment = "<a href=\"\(escapeAttribute(link.absoluteString))\">\(fragment)</a>"
            }
            html += fragment
        }

        return applyingHighlights(to: html)
    }

    /// `==highlight==` is not CommonMark, so it is applied after the fact. The
    /// text is already escaped at this point, so this can never inject markup.
    private static func applyingHighlights(to html: String) -> String {
        var result = html
        while let open = result.range(of: "=="),
              let close = result.range(of: "==", range: open.upperBound..<result.endIndex),
              close.lowerBound > open.upperBound {
            let content = String(result[open.upperBound..<close.lowerBound])
            result.replaceSubrange(open.lowerBound..<close.upperBound, with: "<mark>\(content)</mark>")
        }
        return result
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeAttribute(_ text: String) -> String {
        escape(text).replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Stylesheet

    private static let stylesheet = """
        :root {
          color-scheme: light dark;
          --ink: #1d1d1f;
          --ink-secondary: #6e6e73;
          --rule: rgba(0, 0, 0, 0.12);
          --surface: #ffffff;
          --fill: rgba(0, 0, 0, 0.045);
          --accent: #0071e3;
          --highlight: rgba(255, 214, 10, 0.45);
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --ink: #f5f5f7;
            --ink-secondary: #98989d;
            --rule: rgba(255, 255, 255, 0.16);
            --surface: #1c1c1e;
            --fill: rgba(255, 255, 255, 0.07);
            --accent: #0a84ff;
            --highlight: rgba(255, 214, 10, 0.28);
          }
        }
        * { box-sizing: border-box; }
        body {
          margin: 0;
          padding: 4rem 1.5rem 6rem;
          background: var(--surface);
          color: var(--ink);
          font: 400 17px/1.6 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
          -webkit-font-smoothing: antialiased;
        }
        main { max-width: 42rem; margin: 0 auto; }
        h1, h2, h3, h4, h5, h6 {
          line-height: 1.2;
          letter-spacing: -0.02em;
          margin: 2.2em 0 0.6em;
          font-weight: 700;
        }
        h1 { font-size: 2.2rem; margin-top: 0; letter-spacing: -0.03em; }
        h2 { font-size: 1.65rem; padding-bottom: 0.3em; border-bottom: 1px solid var(--rule); }
        h3 { font-size: 1.3rem; }
        h4, h5, h6 { font-size: 1.05rem; }
        p, ul, ol, blockquote, pre, table { margin: 0 0 1.15em; }
        a { color: var(--accent); text-decoration: none; }
        a:hover { text-decoration: underline; }
        strong { font-weight: 650; }
        mark { background: var(--highlight); color: inherit; border-radius: 3px; padding: 0 0.15em; }
        code {
          font: 0.88em/1.5 ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
          background: var(--fill);
          border-radius: 5px;
          padding: 0.15em 0.4em;
        }
        pre {
          background: var(--fill);
          border-radius: 12px;
          padding: 1rem 1.15rem;
          overflow-x: auto;
        }
        pre code { background: none; padding: 0; font-size: 0.85rem; }
        blockquote {
          border-left: 3px solid var(--rule);
          margin-left: 0;
          padding: 0.1em 0 0.1em 1.15em;
          color: var(--ink-secondary);
        }
        ul, ol { padding-left: 1.5em; }
        li { margin: 0.3em 0; }
        ul.task-list { list-style: none; padding-left: 0.25em; }
        ul.task-list input { margin-right: 0.5em; }
        hr { border: none; border-top: 1px solid var(--rule); margin: 2.5em 0; }
        table { border-collapse: collapse; width: 100%; font-size: 0.95rem; }
        th, td { border-bottom: 1px solid var(--rule); padding: 0.55em 0.7em; text-align: left; }
        th { font-weight: 600; }
        tbody tr:nth-child(even) { background: var(--fill); }
        """
}
