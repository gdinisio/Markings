# Changelog

All notable changes to Markings, newest first. Versions match the commit labels
in the repository (`vX.Y - "Details of this commit"`).

---

## v1.7 — Fixed a crash on launch

v1.6 crashed on launch inside SwiftUI's toolbar code
(`AppKitToolbarStrategy.applyItemCustomizations`). The crash report named the
cause precisely: registers `x25`/`x24` held the small string `paragraphStyle`
with its length in `x23`, and `x0` held **23** against the **22** items the
toolbar declared.

That extra item was the search field. `.searchable`, added to the outline
sidebar in v1.6, installs a toolbar item on macOS. A **customizable** toolbar
reconciles every item against its customization set — and an item SwiftUI
installs for itself has no entry to reconcile against, so applying
customizations trapped on the first item it reached.

- The sidebar filter is now a plain field inside the sidebar's own content. Same
  capability, and it does not touch the toolbar bridge. A comment at the site
  records why, so it does not get "improved" back into `.searchable`.
- The toolbar's identity is bumped to v3, discarding an arrangement that was
  saved while the window was in a crashing state.
- Item identifiers are namespaced (`markings.bold` rather than `bold`), because
  they share a namespace with the identifiers AppKit and SwiftUI install.
- The two remaining `Picker`s in toolbar items are now checkable menu items
  built from `Toggle`. A `Picker` in a toolbar item had already caused the
  overflow-menu failure in v1.1; there is no longer one anywhere in the toolbar.
- Twenty-two items became fifteen. Image, table, code block and divider were
  duplicated as individual items *and* inside the Insert menu; indent and export
  have keyboard shortcuts. A shorter customisation sheet is a better one.

---

## v1.6 — Getting around a long document

Scrolling is fine until a document outgrows it, and the outline sidebar costs a
column of width to keep open.

- **View ▸ Go to Heading…** (`⇧⌘O`) — a jump list: type a few letters, press
  Return. `↑` `↓` choose, `esc` closes, and the keyboard hints are along the
  bottom so none of that has to be guessed.
- Matching is case- and accent-insensitive. A run of the typed letters ranks
  above letters merely scattered in order, so "set" puts *Setup* above *Reset*,
  while `gs` still finds *Getting started*.
- Each result shows the section it sits under, so two headings with the same
  name are told apart by something more useful than a line number.
- The **outline sidebar now has a search field**, using the system's own
  `searchable` field rather than a lookalike. It filters in document order
  rather than by relevance, because an outline sorted by relevance is no longer
  an outline — which is why the sidebar and the jump list use two different
  entry points into the same matching.
- Thirteen more assertions, covering ranking, subsequence matching, tie
  stability and the order guarantee.

---

## v1.5 — Tests for the logic layer

About fifteen hundred lines of parser and editing logic had never been executed.
This adds 229 assertions over it, in `Markings/MarkingsTests/`.

- `MarkdownTransformsTests` checks the **resulting selection** on every command,
  not only the resulting text. The selection is where the offset arithmetic
  actually goes wrong, and a command that edits correctly but leaves the caret in
  the wrong place is still broken.
- `MarkdownParserTests` pins the **source line numbers** of every block, because
  the preview's scroll sync and its task checkboxes both edit by line: a parser
  that gets the structure right and the line numbers wrong ticks the wrong box.
  It also asserts sibling blocks never share an identity, since the preview uses
  those as view identities and scroll targets.
- No-op cases are asserted to return `nil` rather than an identity edit — an
  undo step that does nothing is worse than no command.
- `MarkdownHTMLExporterTests` checks that document text can never become markup,
  including a quote mark in a link target trying to break out of its attribute.
- A robustness test feeds the parser every awkward input I could think of —
  lone markers, unterminated fences, deeply buried items — to confirm it
  terminates and returns something.

The folder is a deliberate **sibling** of `Markings/`, not inside it: the app
target uses a file system synchronized group, so a test file under
`Markings/Markings/` would be compiled into the app, where `import Testing` does
not build. Its README has the one-time Xcode steps to add the target.

---

## v1.4 — One canvas, not two panes

The window was a source pane and a preview pane with a divider between them,
which is the least interesting thing a Markdown editor can be. The writing
surface is now the document.

**Syntax that gets out of the way**

- Markdown markers fade almost to nothing away from the caret, and return at
  full strength on the line being edited. Headings, quotes, code, lists and
  emphasis were already styled; hiding the punctuation is what turns styled
  source into a document you can read.
- Nothing reflows when a marker reveals itself, because it never stopped
  occupying its space — the alternative, deleting the characters from the layout,
  makes text jump under the caret.
- **View ▸ Always Show Markdown Syntax** and a Settings picker turn it off, for
  anyone who would rather see everything.

**A page, not a rectangle**

- Both panes now set the text column on its own lit page against a recessed
  ground, using system colours so it follows the appearance. A column floating
  in a full-bleed white rectangle gives no sense of where the writing area ends;
  the chosen line width just looks like wasted room.

**A status bar that says where you are**

- The left side is now the heading path — `Introduction › Getting started` —
  rather than nothing. Each crumb jumps to its heading. "Which section am I in"
  is the question a writer is actually asking; the line number is on the right
  where it belongs.

**Naming**

- The views are Write, Split and Read. They are named for what you are doing,
  not for which half of the machinery is showing.

---

## v1.3 — A welcome window

Markings now opens on a welcome window instead of an empty untitled document or
a bare Open panel.

- **Hero** — the app name set in the rounded system face over an accent-tinted
  gradient under a material, so it picks up whatever accent colour is set in
  System Settings and stays legible in either appearance. The mark is a page of
  formatted text drawn in SwiftUI rather than shipped as an asset, and its lines
  draw themselves in on appear — enough motion to feel alive, not enough to sit
  through twice.
- **Start** — New Document, New from Clipboard (which reports how many words are
  waiting, and disables itself when there is nothing), and Open….
- **Templates** — Meeting Notes, Read Me, Checklist and Article. All ordinary
  Markdown; a blank page is faster than a page you have to delete first.
- **Recent** — straight from `NSDocumentController`, with folder and modified
  date, a Show in Finder contextual item, and Clear Recents. A file that has
  moved since is dropped from the list rather than failing silently.
- The footer checkbox switches the window off and **Window ▸ Welcome to
  Markings** brings it back; it is also in Settings. With it off, the standard
  launch behaviour returns, because an app that ignores that preference is worse
  than one that never offered it.

---

## v1.2 — App icon

- An Icon Composer `Markings.icon` is now part of the target, and the app has a
  display name. The welcome window shows it rather than a drawn stand-in — the
  real icon is the app's identity and is already better drawn than anything
  assembled in code.

---

## v1.1 — Fixed a toolbar that had collapsed into an overflow chevron

The toolbar was showing nothing but a `»` at its trailing edge, and latterly
that chevron opened nothing at all. Three causes, all now fixed:

- **The toolbar was attached to the `NavigationSplitView`.** Items declared
  there are assigned to the split view's *leading* toolbar section — which is
  only as wide as the sidebar, around 200 points. Every item overflowed. The
  toolbar now belongs to the detail view, where the width is.
- **A fixed-width `Picker` and a segmented `Picker` were direct toolbar items.**
  A bare `Picker` has no menu form representation, so it cannot appear in the
  overflow menu — which is why the chevron eventually opened onto nothing. Both
  are now compact `Menu`s carrying a `Label`, with an inline `Picker` inside
  where a checkmarked list of choices belongs. The view-mode item's icon now
  reports which view you are in rather than only that a choice exists.
- **The saved toolbar configuration was unrecoverable.** The toolbar identity
  carries a version now, so bumping it discards the broken arrangement and
  starts clean.

Also: Link is a default toolbar item, since it is one of the most used commands
and was previously buried in the Insert menu.

---

## v1.0 — A menu bar worth using

**Reorganised**

- Commands are grouped where a person would look for them: Format for how text
  reads, a new top-level **Insert** menu for things added to it (the shape Pages
  uses), Edit for moving text around, View for how it is shown.
- Headings moved into a submenu so the Format menu stays scannable.

**New editing commands**

- **Move Line Up / Down** (`⌥⌘↑` / `⌥⌘↓`) — moves the lines the selection touches,
  and is unavailable at the ends of the document rather than quietly spending an
  undo step.
- **Raise / Lower Heading Level** (`⌃⌘↑` / `⌃⌘↓`) — Heading 2 becomes Heading 1 and
  back. Raising body text makes it a Heading 1; lowering past Heading 6 returns
  it to body. List items and quotes are left alone.
- **Copy as HTML** and **Copy as Plain Text**. Plain text keeps the structure
  plain text can carry — bullets, numbering, checkboxes, indentation, and
  tab-separated table rows that paste straight into a spreadsheet. Both act on
  the selection if there is one, otherwise the whole document.
- **Export as HTML** gained `⇧⌘E`.
- **Follow the Caret in Split View** is now switchable from the View menu, not
  only from Settings.

**Help**

- The stock Help item would only ever have produced an error, since Markings
  ships no help book. It is replaced by **Markdown Syntax** (`⇧⌘/`), a reference
  window listing every construct Markings understands, how to write it, and the
  shortcut that writes it for you.

---

## v0.9 — Customisable toolbar

- The toolbar is now customisable the way Finder's is, using the system
  mechanism rather than an imitation of it: `.toolbar(id:)` with a stable
  identity per item, so right-clicking the toolbar or choosing
  **View ▸ Customize Toolbar…** opens the standard sheet. Items drag in, out and
  reorder; spaces and the icon/text display options come from macOS.
- Every command is its own identified item instead of four buttons sharing one
  expanding slot. A group cannot be taken apart in the customisation sheet, and
  it occupies the same room whether or not you use all of it.
- The default arrangement is deliberately short — paragraph style, bold, italic,
  bulleted list, task list, Insert, view mode, document info — with thirteen
  more items available to drag in.
- Added `ToolbarCommands()` so Show/Hide Toolbar and Customize Toolbar… appear
  in the View menu as well as on the toolbar's contextual menu.

---

## v0.8 — First-build fixes

- `CGSize` has `Int`, `Double` and `CGFloat` initialiser overloads, so a leading
  dot on either argument has nothing to resolve against. The text container and
  the text view's `maxSize` now name `CGFloat` explicitly. This also cleared the
  follow-on error on `autoresizingMask`: the failed `NSTextContainer` left
  `textView` without a type, so `[.width]` had no context either.
- The table view iterates indices rather than `Array(_:enumerated())` with a key
  path into a tuple, which is both safer to compile and easier to read.

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
