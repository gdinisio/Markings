# Changelog

All notable changes to Markings, newest first. Versions match the commit labels
in the repository (`vX.Y - "Details of this commit"`).

---

## v0.7 — Explicit module imports and reliable editor sizing

- The target enables `MEMBER_IMPORT_VISIBILITY`, so a module must be imported
  directly for its members to be visible. Every file now imports what it
  actually uses rather than relying on SwiftUI to bring Foundation along.
- The source editor sizes its text view to the clip view explicitly when the
  window resizes, rather than trusting autoresizing to have started from a
  matching width — not guaranteed for a view created at zero size inside an
  `NSViewRepresentable`.

---

## v0.6 — Documentation

- Added `README.md`: what the app does, how to build it, how to use it, the full
  keyboard shortcut table, the architecture, the implementation decisions behind
  it, exactly what Markdown is and is not supported, and the steps that belong
  in Xcode rather than in the source tree.
- Added this changelog.

---

## v0.5 — Document workspace, toolbar, menu bar and settings

**Window**

- Document window built as a `NavigationSplitView`: outline sidebar, document,
  and an inspector on the trailing edge.
- Three view modes — Editor, Split and Preview — on `⌘1` / `⌘2` / `⌘3`. In Split
  view the reading side follows the caret, so what you are writing stays in
  front of you.
- Outline sidebar lists the document's headings, marks the one the caret is in,
  and jumps to any of them. Show/Hide Sidebar is the system's own menu item
  wired to the split view rather than a lookalike of it.
- Document inspector reporting length, structure, task progress and the file,
  with *Show in Finder*.
- A quiet status bar with the word count, reading time, task progress and caret
  position. It can be switched off from the View menu.
- New documents start empty, with a placeholder set exactly where the first
  character will land, at any line width.

**Toolbar**

- Leads with a paragraph-style pop-up that reports the style of the current line
  as well as setting it.
- Inline formatting and list controls as grouped controls; everything else in an
  Insert menu.
- View-mode picker and inspector toggle on the trailing edge.
- Formatting controls disable themselves in Preview view, so what is available
  is always visible.

**Menu bar**

- A full Format menu: every inline style, every paragraph style, lists, quotes,
  code blocks, tables, dividers, task completion and indentation, each with a
  keyboard shortcut.
- Find, Find and Replace, Find Next/Previous and Use Selection for Find on the
  standard shortcuts, driving `NSTextView`'s own find bar.
- View menu additions: view modes, inspector, Focus Mode, word count, and text
  size.

**Settings**

- A tabbed settings window of grouped forms — Editing and Reading — with
  typeface, text size, line height, line width, Focus Mode, indent step, and
  each smart-editing behaviour individually switchable.
- A live type sample in the Reading tab.

**Export**

- *File ▸ Export as HTML…* writes a self-contained HTML file styled to match the
  reading view. Failures are reported rather than swallowed.

---

## v0.4 — Reading view for the rendered document

- Headings scale as one hierarchy from a single base size, with a rule under the
  first two levels.
- Block quotes take an accent rule and recede; thematic breaks become real
  dividers; nested lists step in with their own bullet glyph per depth.
- Code blocks sit on a tinted, rounded ground with the language named and a Copy
  button that confirms itself, and scroll horizontally rather than forcing the
  whole page to.
- Tables use a real `Grid`, so columns size to their content and honour the
  alignment declared in the delimiter row.
- Task checkboxes are live: clicking one edits the exact source line it came
  from.
- Text is selectable throughout, and the reading column is held to the measure
  chosen in Settings.
- Image references are shown as a labelled card naming their target. A sandboxed
  app has no access to files beside the document, and fetching remote images
  would need a network entitlement that has not been asked for.

---

## v0.3 — Native source editor with live Markdown syntax highlighting

- Source editor built on `NSTextView`. SwiftUI's `TextEditor` cannot express
  syntax highlighting, list continuation, or any command that needs to know
  where the selection is.
- Live syntax highlighting: headings scale and bold, quotes recede, list markers
  take the accent colour, fenced and inline code turn monospaced on a tinted
  ground, links show their target in link colour, completed tasks are struck
  through, and table source is monospaced so columns line up while you edit them.
- Wrapped list and quote lines hang under their own text rather than sliding
  back under the bullet.
- Every colour resolves from a system colour, so the editor follows the
  appearance and accent colour the user chose.
- Smart editing: Return continues bulleted, numbered, task and quote items and
  ends the list when the item is empty; Tab and Shift-Tab nest and un-nest to
  the parent item's content column; typing a pair character over a selection
  wraps it; pasting a URL over selected text makes a link.
- Automatic quote, dash and text substitution turned off, because they silently
  corrupt Markdown source. Spell checking left on for prose.
- Focus Mode dims everything but the paragraph being written.
- `EditorController` is the single route from the toolbar, the menu bar and the
  outline to the text, so every path performs the same edit and lands in the
  same undo group.
- Highlighting is coalesced while typing; inline passes are skipped past 400,000
  characters so very large files stay responsive.

---

## v0.2 — Markdown model: parser, outline, statistics and editing transforms

- `MarkdownLine` splits one source line into indent, block marker, task checkbox
  and content, and composes it back again.
- `MarkdownParser` covers ATX and Setext headings, paragraphs with hard line
  breaks, fenced code, nested block quotes, bulleted/ordered/task lists with
  nesting, GitHub tables and thematic breaks. Every block records the source
  lines it came from.
- Inline syntax delegated to Foundation's Markdown parser rather than
  reimplemented.
- `MarkdownTransforms` turns every formatting command into a single contiguous
  edit. Indent and outdent follow the parent item's content column, so nesting
  stays valid CommonMark for both bullets and numbered lists.
- `DocumentOutline` and `DocumentStatistics` read from the parsed document, so
  word counts are not inflated by syntax, code blocks or link targets.
- `MarkdownHTMLExporter` renders a self-contained HTML file with light and dark
  support.

---

## v0.1 — Markdown document type and repository hygiene

- `MarkingsDocument` reads and writes UTF-8 plain text, imports the
  `net.daringfireball.markdown` identifier, and accepts `.md`, `.markdown`,
  `.mdown`, `.mkd`, `.mkdn`, `.mdtext` and plain text.
- Line endings normalised to `LF` on read.
- Falls back to Latin-1 when a legacy file is not valid UTF-8, rather than
  refusing to open it.
- `Info.plist` declares both document types with sensible handler ranks.
- Added a `.gitignore` for macOS and Xcode noise; stopped tracking `.DS_Store`
  and per-user Xcode state.

---

## v0.0 — Empty Xcode project

- Baseline macOS document-based app from the Xcode Document App template:
  the Markings target, bundle identifier, sandboxing and the SwiftUI
  `DocumentGroup` scaffold.
