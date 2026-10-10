# Markings

A Markdown reader and editor for macOS, built with SwiftUI and AppKit.

Markings writes plain UTF-8 Markdown — no proprietary format, no lock-in. A file
written in Markings opens anywhere, and a file written anywhere else opens in
Markings. What the app adds is the part that is usually missing: source that
reads like the document it describes, a reading view worth reading, and every
formatting command reachable from the keyboard.

---

## Contents

- [What it does](#what-it-does)
- [Getting started](#getting-started)
- [Using Markings](#using-markings)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Architecture](#architecture)
- [Implementation notes](#implementation-notes)
- [Markdown support](#markdown-support)
- [Things to do in Xcode by hand](#things-to-do-in-xcode-by-hand)

---

## What it does

**Writing.** The source editor styles Markdown as you type. Headings scale and
bold, block quotes recede, list markers take the accent colour, code turns
monospaced on a tinted ground, links show their target in link colour, and
completed tasks are struck through. Syntax characters stay visible — this is a
source editor, not a hidden-markup one — but they are quiet enough to read past.

**Reading.** The reading view renders the document in system typography with a
comfortable measure: real headings, dividers, block quotes, nested lists,
tables that size to their content, and code blocks with a Copy button. Task
checkboxes are live — clicking one edits the source line it came from.

**Moving around.** The outline sidebar lists the document's headings, marks the
one the caret is in, and jumps to any of them. In Split view the reading side
follows the caret as you write.

**Knowing what you have.** The inspector reports words, characters, lines,
reading time, headings, links, images, code blocks, tables and task progress.
A quiet status bar keeps the word count and caret position in view.

---

## Getting started

**Requirements** — Xcode 27 or later, macOS 27 or later.

```sh
git clone https://github.com/gdinisio/markings.git
cd markings
open Markings/Markings.xcodeproj
```

Select the **Markings** scheme and run (`⌘R`).

The project uses an Xcode *file system synchronized group*, so any `.swift` file
added anywhere under `Markings/Markings/` is compiled automatically — there is
no project file to edit when adding a source file.

---

## Using Markings

### One canvas

The default view is not a source pane waiting for a preview beside it. It is a
single page where the Markdown *is* the document: headings sized, quotes
indented, code monospaced on its own ground, lists hanging — and the syntax
characters themselves faded almost to nothing.

Put the caret on a line and its markers come back at full strength, ready to
edit. Move away and they recede again. Nothing shifts when they do, because they
never stopped occupying their space.

Switch it off with **View ▸ Always Show Markdown Syntax** if you would rather
see everything all the time.

Three views, from the toolbar or `⌘1` / `⌘2` / `⌘3`:

| View | What it is |
| --- | --- |
| **Write** | One canvas, syntax revealed where you are working |
| **Split** | Writing and reading side by side, the reading side following the caret |
| **Read** | The finished document on its own |

Each sits on a page: the text column on its own lit surface against a recessed
ground, so the line width you chose reads as deliberate rather than as leftover
room.

Along the bottom, the heading path shows which section you are in — click any
part of it to jump there — with the word count and reading time on the right.

### Getting around a long document

**View ▸ Go to Heading…** (`⇧⌘O`) opens a jump list: type a few letters, press
Return. Matching is case- and accent-insensitive, a run of letters ranks above
letters merely scattered in order (so `gs` still finds "Getting started"), and
each result shows the section it sits under so two headings with the same name
are told apart by something better than a line number. `↑` `↓` choose, `esc`
closes.

The outline sidebar has a search field of its own. It filters in **document
order** rather than by relevance — an outline sorted by relevance is no longer
an outline.

### The welcome window

Markings opens on a welcome window rather than an empty untitled document or a
bare Open panel. It answers the three things you actually want at launch:

- **Start** — a new document, one from the clipboard, or the Open panel
- **Templates** — Meeting Notes, Read Me, Checklist, Article, all ordinary
  Markdown with nothing to delete first
- **Recent** — the documents you had, with folder and date, straight from
  `NSDocumentController`

The checkbox in its footer switches it off, and **Window ▸ Welcome to Markings**
brings it back. With it switched off, the standard launch behaviour returns.

### The toolbar

The toolbar is customisable exactly the way Finder's is, because it *is* that
mechanism: right-click it, or choose **View ▸ Customize Toolbar…**, and every
command can be dragged in, dragged out and reordered. Spaces, flexible spaces
and the icon/text display options come from macOS itself.

Every control is its own item rather than a group sharing one slot, so you can
take exactly what you want. Shown by default:

> paragraph style · **B** · *I* · link · bulleted list · task list · Insert ·
> view mode · document info

Every item is a button or a menu carrying a label, which is what gives it a name
in the customisation sheet and a working entry in the overflow menu if the
window is ever genuinely too narrow.

Waiting in the customisation sheet: strikethrough, inline code, highlight,
numbered list, block quote, increase/decrease indent, link, image, table, code
block, divider, Focus Mode and Export as HTML.

Formatting controls dim in Preview rather than disappearing, so what is
unavailable stays visible.

### Smart editing

These behave the way they do in Notes and Mail, and each one can be switched off
in Settings if it gets in the way:

- **Return** continues a bulleted, numbered, task or quote item, numbering the
  next one for you. Pressing Return on an empty item ends the list.
- **Tab** and **Shift-Tab** nest and un-nest list items. Nesting lines up with
  the parent item's content column, so it stays valid CommonMark for both
  bullets (two columns) and numbered items (three).
- Typing `*`, `_`, `` ` ``, `~`, `"`, `(`, `[` or `{` **over a selection wraps
  it** rather than replacing it.
- **Pasting a URL over selected text** makes a link out of it. Every other
  paste stays plain text, because pasted styling has no meaning in a source file.
- Automatic quote, dash and text substitution are **off** — smart quotes break
  code spans and en dashes break thematic breaks. Spell checking stays on.

### Focus Mode

`⇧⌘F` dims everything except the paragraph you are writing.

### Export

**File ▸ Export as HTML…** (`⇧⌘E`) writes a single self-contained HTML file,
styled to match the reading view, with light and dark support built in.

**Edit ▸ Copy as HTML** puts the HTML source on the clipboard. **Copy as Plain
Text** strips the syntax instead, keeping bullets, numbering, checkboxes and
tab-separated table rows, so what you paste into a message or a spreadsheet
reads properly. Both act on the selection if there is one, otherwise the whole
document.

---

## Menu bar

On macOS the menu bar — not the toolbar — is the complete index of what an app
can do, and Markings treats it that way. Everything is grouped where you would
look for it: **Format** for how text reads, **Insert** for things added to it,
**Edit** for moving it around, **View** for how it is shown. Items disable
rather than disappear when no document has focus, so the shape of the app stays
the same whatever is in front of you.

**Help ▸ Markdown Syntax** (`⇧⌘/`) opens a reference window listing every piece
of syntax Markings understands alongside the shortcut that writes it.

---

## Keyboard shortcuts

### Format

| Command | Shortcut | | Command | Shortcut |
| --- | --- | --- | --- | --- |
| Bold | `⌘B` | | Body | `⌥⌘0` |
| Italic | `⌘I` | | Heading 1–6 | `⌥⌘1`–`⌥⌘6` |
| Strikethrough | `⇧⌘X` | | Raise Heading Level | `⌃⌘↑` |
| Inline Code | `⌃⌘C` | | Lower Heading Level | `⌃⌘↓` |
| Highlight | `⌃⌘H` | | Bulleted List | `⇧⌘7` |
| Increase Indent | `⌘]` | | Numbered List | `⇧⌘8` |
| Decrease Indent | `⌘[` | | Task List | `⇧⌘L` |
| | | | Block Quote | `⌥⌘B` |
| | | | Mark Task as Done | `⇧⌘D` |

### Insert

`⌘K` Link · `⌃⌘I` Image · `⌃⌘T` Table · `⌥⌘C` Code Block · `⇧⌘-` Divider

### Edit

`⌥⌘↑` / `⌥⌘↓` Move Line Up/Down · Copy as HTML · Copy as Plain Text

`⌘F` Find · `⌥⌘F` Find and Replace · `⌘G` Find Next · `⇧⌘G` Find Previous ·
`⌘E` Use Selection for Find

### View

`⇧⌘O` Go to Heading · `⌘1` Editor · `⌘2` Split · `⌘3` Preview · `⌃⌘S` Show/Hide Sidebar ·
`⌥⌘I` Show/Hide Document Info · `⇧⌘F` Focus Mode · `⌘+` / `⌘-` Text Size ·
`⌘0` Actual Size

### File and Help

`⇧⌘E` Export as HTML · `⇧⌘/` Markdown Syntax

---

## Architecture

```
Markings/Markings/
├── MarkingsApp.swift          App and scenes
├── Document/                  The file on disk
│   ├── MarkingsDocument.swift     FileDocument for plain-text Markdown
│   └── HTMLExportDocument.swift   Drives the export save panel
├── Model/                     Pure Foundation, no UI
│   ├── MarkdownLine.swift         One source line, parsed and composable
│   ├── MarkdownBlock.swift        The parsed block tree
│   ├── MarkdownParser.swift       Block-level parser
│   ├── MarkdownTransforms.swift   Every editing command, as a pure function
│   ├── MarkdownInlineText.swift   Inline parsing via Foundation
│   ├── DocumentOutline.swift      Headings
│   ├── DocumentStatistics.swift   Counts
│   └── MarkdownHTMLExporter.swift Block tree → HTML
├── Editor/                    Writing
│   ├── EditorTheme.swift          Fonts and semantic colours
│   ├── MarkdownSyntaxHighlighter.swift
│   ├── SourceEditor.swift         NSTextView, wrapped
│   └── EditorController.swift     One route from every command to the text
├── Preview/                   Reading
│   ├── InlineMarkdown.swift       Inline Markdown → styled SwiftUI Text
│   └── MarkdownPreview.swift      Block views
├── Workspace/                 The window
│   ├── ContentView.swift          Split view, panes, wiring
│   ├── WorkspaceToolbar.swift
│   ├── MarkingsCommands.swift     Menu bar
│   ├── OutlineSidebar.swift
│   ├── DocumentInspector.swift
│   ├── EditorStatusBar.swift
│   ├── SettingsView.swift
│   └── FocusedValues.swift        Menu commands → focused document
└── Support/
    └── AppSettings.swift          Preference keys, defaults, shared enums
```

The dependency direction is one-way: `Workspace` → `Editor`/`Preview` → `Model`.
Nothing in `Model` knows the app has a user interface, which is what keeps the
parser and the editing commands small enough to reason about.

**One route to every edit.** The toolbar, the menu bar, the outline and the
editor's own key handling all call `EditorController`, which turns the request
into a single contiguous `TextEdit` and applies it through `NSTextView`. Every
path therefore performs the same edit, registers the same undo, and posts the
same accessibility notification.

---

## Implementation notes

**Why `NSTextView` and not SwiftUI's `TextEditor`.** `TextEditor` cannot express
syntax highlighting, list continuation, or any command that needs to know where
the selection is. `NSTextView` is itself the native macOS text editing control —
wrapping it is using the platform, not working around it. It also brings the
system find bar, spell checking, services, dictation and accessibility for free.

**TextKit 1, on purpose.** The editor builds its text stack explicitly
(`NSTextStorage` → `NSLayoutManager` → `NSTextContainer`) rather than taking the
default. The highlighter needs the storage, and revealing an outline heading
needs the layout manager to measure where a line actually is.

**Blocks parsed here, inline parsed by Foundation.** Markings parses block
structure itself because it needs something Foundation does not provide: the
source line every block came from. That is what lets the reading view follow the
caret, and what lets a checkbox clicked in the preview edit the exact line it
came from. Inline syntax is handed to Foundation's Markdown parser, which is
well tested and behaves the way the rest of the platform does.

**Undo.** Edits go through `shouldChangeText(in:replacementString:)` /
`didChangeText()`, so `NSTextView` registers them with the document's undo
manager. Because `NSUndoManager` groups by event, an edit and the document
binding update that follows it land in the same undo group and are undone
together.

**Highlighting cost.** Highlighting is coalesced while typing rather than run on
every keystroke. Past 400,000 characters the inline passes are skipped and only
block-level styling is applied, so a very large file stays responsive. Parsing
for the reading view is debounced separately.

**Images are shown, not rendered.** A sandboxed app has no access to files
beside the document, and fetching remote images would need a network entitlement
that has not been asked for. Rather than show a broken image well, the reading
view shows a labelled card naming what the reference points at. Rendering images
for real would mean adding `com.apple.security.network.client` and a
security-scoped bookmark for the document's folder — a deliberate decision, not
a default.

**Colours.** Every colour in the editor resolves from a system colour, so the
app follows the appearance and accent colour the user has chosen instead of
inventing a palette of its own.

---

## Markdown support

Parsed and rendered: ATX (`#`) and Setext (`===`) headings, paragraphs with hard
line breaks, fenced code with a language tag, nested block quotes, bulleted,
numbered and task lists with nesting, GitHub-style tables with column alignment,
thematic breaks, and all standard inline syntax — emphasis, strong emphasis,
code spans, strikethrough, links, images and autolinks.

Two deliberate departures from CommonMark:

- `==highlight==` is supported in the editor, the reading view and HTML export.
  It is not CommonMark, but it is common enough across Markdown apps to be worth
  having, and it degrades to literal text elsewhere.
- Line endings are normalised to `LF` when a file is read, so every parser,
  offset and edit only ever deals with one form.

Not supported: reference-style links, footnotes, definition lists, inline HTML
rendering (it is passed through as text), and lazy list continuation — a
continuation line must be indented to its item's content column.

---

## Things to do in Xcode by hand

These are Xcode's to own, not the source tree's:

1. **Signing.** `DEVELOPMENT_TEAM` is already set and signing is automatic.
   Check it in *Signing & Capabilities* before archiving.
2. **Sandbox.** The app sandbox and user-selected file access are on via build
   settings, so Xcode generates the entitlements. If image loading or anything
   else that needs the network is added later, the network client entitlement
   has to be turned on deliberately.

---

## Tests

`Markings/MarkingsTests/` holds 242 assertions over the model layer — the
parser, the editing transforms, the outline, the statistics and both exporters.
All of it is pure Foundation, so it runs without a window.

The folder sits beside `Markings/` rather than inside it, because the app target
uses a file system synchronized group and a test file under `Markings/Markings/`
would be compiled into the app. `MarkingsTests/README.md` has the one-time Xcode
steps to add the target; after that it is `⌘U`.

---

## Conventions

Commits are labelled `vX.Y - "Details of this commit"`, each with a description
of what changed and why. `README.md` and `CHANGELOG.md` are kept current as part
of the work rather than afterwards.
