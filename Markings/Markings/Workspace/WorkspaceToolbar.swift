//
//  WorkspaceToolbar.swift
//  Markings
//

import Foundation
import SwiftUI

/// Stable identities for every toolbar item.
///
/// macOS persists a customised toolbar against these strings. The toolbar
/// identity carries a version because the previous arrangement was unusable —
/// bumping it discards any saved configuration and starts everyone clean.
/// Individual item identities must not change for that reason: renaming one
/// silently drops it for anyone who had already placed it.
nonisolated enum ToolbarID {
    static let toolbar = "markings.document.toolbar.v2"

    static let paragraphStyle = "paragraphStyle"
    static let bold = "bold"
    static let italic = "italic"
    static let strikethrough = "strikethrough"
    static let inlineCode = "inlineCode"
    static let highlight = "highlight"

    static let bulletedList = "bulletedList"
    static let numberedList = "numberedList"
    static let taskList = "taskList"
    static let blockQuote = "blockQuote"
    static let increaseIndent = "increaseIndent"
    static let decreaseIndent = "decreaseIndent"

    static let insert = "insert"
    static let link = "link"
    static let image = "image"
    static let table = "table"
    static let codeBlock = "codeBlock"
    static let divider = "divider"

    static let viewMode = "viewMode"
    static let inspector = "inspector"
    static let focusMode = "focusMode"
    static let exportHTML = "exportHTML"
}

/// The document window's toolbar.
///
/// Two rules keep it working rather than collapsing into an overflow chevron:
///
/// 1. It is attached to the **detail** view, not to the `NavigationSplitView`.
///    Items declared on the split view are assigned to its leading section,
///    which is only as wide as the sidebar — so every item overflows.
/// 2. Every item is a `Button` or a `Menu` carrying a `Label`. Those get an
///    automatic menu form representation, so when the window *is* too narrow
///    the overflow menu still lists them. A bare `Picker` has none, and a
///    fixed-width control makes overflow arrive far sooner than it needs to.
///
/// Each command is its own identified item, which is what makes the toolbar
/// customisable the way Finder's is: right-click it, or choose
/// View ▸ Customize Toolbar…, and items drag in, out and reorder.
struct WorkspaceToolbar: CustomizableToolbarContent {

    var controller: EditorController
    @Binding var mode: WorkspaceMode
    @Binding var showInspector: Bool
    @Binding var focusMode: Bool
    @Binding var exportRequested: Bool
    /// Formatting is meaningless in Preview, so those items dim rather than
    /// disappear — what is unavailable stays visible.
    var isEditing: Bool

    var body: some CustomizableToolbarContent {
        TextStyleToolbarItems(controller: controller, isEditing: isEditing)
        StructureToolbarItems(controller: controller, isEditing: isEditing)
        InsertToolbarItems(controller: controller, isEditing: isEditing)
        DocumentToolbarItems(mode: $mode,
                             showInspector: $showInspector,
                             focusMode: $focusMode,
                             exportRequested: $exportRequested)
    }
}

// MARK: - Text styles

private struct TextStyleToolbarItems: CustomizableToolbarContent {

    var controller: EditorController
    var isEditing: Bool

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: ToolbarID.paragraphStyle, showsByDefault: true) {
            Menu {
                // An inline Picker inside a menu is how macOS shows a set of
                // mutually exclusive choices with a checkmark on the current one.
                Picker("Paragraph Style", selection: styleSelection) {
                    Text("Body").tag(BlockStyle.body)
                    ForEach(1...6, id: \.self) { level in
                        Text("Heading \(level)").tag(BlockStyle.heading(level))
                    }
                    Text("Bulleted List").tag(BlockStyle.bulletList)
                    Text("Numbered List").tag(BlockStyle.numberedList)
                    Text("Task List").tag(BlockStyle.taskList)
                    Text("Block Quote").tag(BlockStyle.quote)
                }
                .pickerStyle(.inline)
            } label: {
                Label("Paragraph Style", systemImage: "textformat")
            }
            .disabled(!isEditing)
            .help("Paragraph style of the current line")
        }

        ToolbarItem(id: ToolbarID.bold, showsByDefault: true) {
            ToolbarCommandButton("Bold", "bold", enabled: isEditing) { controller.toggleBold() }
        }

        ToolbarItem(id: ToolbarID.italic, showsByDefault: true) {
            ToolbarCommandButton("Italic", "italic", enabled: isEditing) { controller.toggleItalic() }
        }

        ToolbarItem(id: ToolbarID.strikethrough, showsByDefault: false) {
            ToolbarCommandButton("Strikethrough", "strikethrough", enabled: isEditing) {
                controller.toggleStrikethrough()
            }
        }

        ToolbarItem(id: ToolbarID.inlineCode, showsByDefault: false) {
            ToolbarCommandButton("Inline Code", "chevron.left.forwardslash.chevron.right", enabled: isEditing) {
                controller.toggleInlineCode()
            }
        }

        ToolbarItem(id: ToolbarID.highlight, showsByDefault: false) {
            ToolbarCommandButton("Highlight", "highlighter", enabled: isEditing) {
                controller.toggleHighlight()
            }
        }
    }

    /// Reports the style of the line the caret is on as well as setting it.
    private var styleSelection: Binding<BlockStyle> {
        Binding {
            controller.blockStyle
        } set: { style in
            controller.apply(style)
        }
    }
}

// MARK: - Structure

private struct StructureToolbarItems: CustomizableToolbarContent {

    var controller: EditorController
    var isEditing: Bool

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: ToolbarID.bulletedList, showsByDefault: true) {
            ToolbarCommandButton("Bulleted List", "list.bullet", enabled: isEditing) {
                controller.toggleBulletList()
            }
        }

        ToolbarItem(id: ToolbarID.taskList, showsByDefault: true) {
            ToolbarCommandButton("Task List", "checklist", enabled: isEditing) {
                controller.toggleTaskList()
            }
        }

        ToolbarItem(id: ToolbarID.numberedList, showsByDefault: false) {
            ToolbarCommandButton("Numbered List", "list.number", enabled: isEditing) {
                controller.toggleNumberedList()
            }
        }

        ToolbarItem(id: ToolbarID.blockQuote, showsByDefault: false) {
            ToolbarCommandButton("Block Quote", "text.quote", enabled: isEditing) {
                controller.toggleBlockQuote()
            }
        }

        ToolbarItem(id: ToolbarID.increaseIndent, showsByDefault: false) {
            ToolbarCommandButton("Increase Indent", "increase.indent", enabled: isEditing) {
                controller.indent()
            }
        }

        ToolbarItem(id: ToolbarID.decreaseIndent, showsByDefault: false) {
            ToolbarCommandButton("Decrease Indent", "decrease.indent", enabled: isEditing) {
                controller.outdent()
            }
        }
    }
}

// MARK: - Insert

private struct InsertToolbarItems: CustomizableToolbarContent {

    var controller: EditorController
    var isEditing: Bool

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: ToolbarID.link, showsByDefault: true) {
            ToolbarCommandButton("Link", "link", enabled: isEditing) { controller.insertLink() }
        }

        // One compact menu by default; the same commands are also available as
        // individual items for anyone who would rather have them one click away.
        ToolbarItem(id: ToolbarID.insert, showsByDefault: true) {
            Menu {
                Button { controller.insertImage() } label: { Label("Image", systemImage: "photo") }
                Divider()
                Button { controller.insertTable() } label: { Label("Table", systemImage: "tablecells") }
                Button { controller.insertCodeBlock() } label: { Label("Code Block", systemImage: "curlybraces") }
                Button { controller.insertThematicBreak() } label: { Label("Divider", systemImage: "minus") }
            } label: {
                Label("Insert", systemImage: "plus")
            }
            .disabled(!isEditing)
            .help("Insert an image, table, code block or divider")
        }

        ToolbarItem(id: ToolbarID.image, showsByDefault: false) {
            ToolbarCommandButton("Image", "photo", enabled: isEditing) { controller.insertImage() }
        }

        ToolbarItem(id: ToolbarID.table, showsByDefault: false) {
            ToolbarCommandButton("Table", "tablecells", enabled: isEditing) { controller.insertTable() }
        }

        ToolbarItem(id: ToolbarID.codeBlock, showsByDefault: false) {
            ToolbarCommandButton("Code Block", "curlybraces", enabled: isEditing) { controller.insertCodeBlock() }
        }

        ToolbarItem(id: ToolbarID.divider, showsByDefault: false) {
            ToolbarCommandButton("Divider", "minus", enabled: isEditing) { controller.insertThematicBreak() }
        }
    }
}

// MARK: - Document

private struct DocumentToolbarItems: CustomizableToolbarContent {

    @Binding var mode: WorkspaceMode
    @Binding var showInspector: Bool
    @Binding var focusMode: Bool
    @Binding var exportRequested: Bool

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: ToolbarID.viewMode, showsByDefault: true) {
            Menu {
                Picker("View", selection: $mode) {
                    ForEach(WorkspaceMode.allCases) { item in
                        Label(item.title, systemImage: item.symbolName).tag(item)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                // The icon reports which view you are in, not just that a
                // choice exists.
                Label("View", systemImage: mode.symbolName)
            }
            .help("Show the source, the reading view, or both")
        }

        ToolbarItem(id: ToolbarID.inspector, showsByDefault: true) {
            Button {
                showInspector.toggle()
            } label: {
                Label("Document Info", systemImage: "sidebar.right")
            }
            .help("Show or hide document information")
        }

        ToolbarItem(id: ToolbarID.focusMode, showsByDefault: false) {
            Button {
                focusMode.toggle()
            } label: {
                Label("Focus Mode", systemImage: focusMode ? "scope" : "circle.dashed")
            }
            .help("Dim everything except the paragraph you are writing")
        }

        ToolbarItem(id: ToolbarID.exportHTML, showsByDefault: false) {
            Button {
                exportRequested = true
            } label: {
                Label("Export as HTML", systemImage: "square.and.arrow.up")
            }
            .help("Export the document as an HTML file")
        }
    }
}

// MARK: - Shared

/// One toolbar button.
///
/// A `Label` rather than a bare `Image`, so the item has a name in the
/// customisation sheet and a usable entry in the overflow menu when the window
/// is genuinely too narrow.
private struct ToolbarCommandButton: View {

    private let title: String
    private let symbol: String
    private let enabled: Bool
    private let action: () -> Void

    init(_ title: String, _ symbol: String, enabled: Bool, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Label(title, systemImage: symbol)
        }
        .help(title)
        .disabled(!enabled)
    }
}
