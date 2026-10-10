# MarkingsTests

Tests for the model layer — the parser, the editing transforms, the outline,
the statistics, and both exporters. Everything here is pure Foundation, so it
runs without a window.

## Adding the target

This folder is deliberately a **sibling** of `Markings/`, not inside it. The app
target uses an Xcode file system synchronized group, so anything under
`Markings/Markings/` is compiled into the app automatically — and `import Testing`
in the app target would not build. Keeping the tests outside that folder means
they can sit in the repository safely until a test target exists.

To wire them up, once, in Xcode:

1. **File ▸ New ▸ Target…** → **Unit Testing Bundle**, named `MarkingsTests`,
   with **Markings** as the target to be tested, and **Swift Testing** as the
   testing system.
2. Xcode creates its own `MarkingsTests` group. Delete the placeholder file it
   generates, then drag this folder's `.swift` files in — or point the target's
   synchronized group at this folder.
3. The tests reach the app's types through `@testable import`-free access: the
   model types are all internal, so add `@testable import Markings` at the top of
   each file if the target does not already pick them up.

Then `⌘U`.

## What is covered

| Suite | What it pins down |
| --- | --- |
| `MarkdownLineTests` | Parse/compose round trips, marker splitting, content columns |
| `MarkdownParserTests` | Every block construct, source line mapping, block identity, awkward input |
| `MarkdownTransformsTests` | Every editing command, its resulting selection, and its no-op cases |
| `DocumentOutlineTests` | Heading extraction and the ancestor path |
| `DocumentStatisticsTests` | Counts taken from prose rather than syntax |
| `MarkdownPlainTextTests` | Structure that survives losing the syntax |
| `MarkdownHTMLExporterTests` | Element mapping, and that document text can never become markup |
| `MarkingsDocumentTests` | Line ending normalisation |

The emphasis is on the two places bugs actually live: the offset arithmetic in
`MarkdownTransforms` (every assertion checks the resulting selection, not just
the resulting text) and the source line numbers in `MarkdownParser`, which the
preview's scroll sync and the preview's task checkboxes both depend on.
