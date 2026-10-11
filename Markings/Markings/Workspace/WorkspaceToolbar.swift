//
//  WorkspaceToolbar.swift
//  Markings
//

import Foundation
import SwiftUI

/// Stable identities for every toolbar item.
///
/// macOS persists a customised toolbar against these strings, so an item's
/// identity must not change once shipped — renaming one drops it for anyone who
/// had already placed it. The *toolbar's* identity carries a version precisely
/// so the whole saved arrangement can be discarded when it has to be.
///
/// Identifiers are namespaced because they share a space with the ones AppKit
/// and SwiftUI install themselves.
nonisolated enum ToolbarID {
    /// v3 discards the v2 arrangement, which was written while the toolbar was
    /// in a state that crashed on launch.
    static let toolbar = "markings.document.toolbar.v3"

    static let paragraphStyle = "markings.paragraphStyle"
    static let bold = "markings.bold"
    static let italic = "markings.italic"
    static let strikethrough = "markings.strikethrough"
    static let inlineCode = "markings.inlineCode"
    static let highlight = "markings.highlight"
    static let link = "markings.link"
    static let insert = "markings.insert"

    static let bulletedList = "markings.bulletedList"
    static let numberedList = "markings.numberedList"
    static let taskList = "markings.taskList"
    static let blockQuote = "markings.blockQuote"
    static let viewMode = "markings.viewMode"
    static let inspector = "markings.inspector"
    static let focusMode = "markings.focusMode"
}

/// The document window's toolbar.
///
/// Three rules, each of them learned the hard way:
///
/// 1. It is attached to the **detail** view, not to the `NavigationSplitView`.
///    Items declared on the split view are assigned to its leading section,
///    which is only as wide as the sidebar, so every one of them overflows.
/// 2. Every item is a `Button` or a `Menu` carrying a `Label`. Those get a menu
///    form representation, so a window too narrow to show them all still lists
///    them in the overflow menu. A bare `Picker` has none.
/// 3. Nothing else in the window may add a toolbar item of its own. A
///    customizable toolbar reconciles every item against its customization set,
///    and an item it did not declare — a `searchable` field, for instance — has
///    no entry to reconcile against.
///
/// Each command is its own identified item, which is what makes the toolbar
/// customisable the way Finder's is: right-click it, or choose
/// View ▸ Customize Toolbar…, and items drag in, out and reorder.
struct WorkspaceToolbar: CustomizableToolbarContent {

    var controller: EditorController
    @Binding var mode: WorkspaceMode
    @Binding var showInspector: Bool
    @Binding var focusMode: Bool
    /// Formatting is meaningless in Preview, so those items dim rather than
    /// disappear — what is unavailable stays visible.
    var isEditing: Bool

    var body: some CustomizableToolbarContent {
        TextToolbarItems(controller: controller, isEditing: isEditing)
        DocumentToolbarItems(controller: controller,
                             mode: $mode,
                             showInspector: $showInspector,
                             focusMode: $focusMode,
                             isEditing: isEditing)
    }
}

// MARK: - Text

private struct TextToolbarItems: CustomizableToolbarContent {

    var controller: EditorController
    var isEditing: Bool

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: ToolbarID.paragraphStyle, showsByDefault: true) {
            Menu {
                styleItem(.body, "Body")
                Divider()
                ForEach(1...6, id: \.self) { level in
                    styleItem(.heading(level), "Heading \(level)")
                }
                Divider()
                styleItem(.bulletList, "Bulleted List")
                styleItem(.numberedList, "Numbered List")
                styleItem(.taskList, "Task List")
                styleItem(.quote, "Block Quote")
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

        ToolbarItem(id: ToolbarID.link, showsByDefault: true) {
            ToolbarCommandButton("Link", "link", enabled: isEditing) { controller.insertLink() }
        }

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
    }

    /// A checkable menu item: it reports the caret's current style as well as
    /// setting it, without a `Picker` in the toolbar.
    private func styleItem(_ style: BlockStyle, _ title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { controller.blockStyle == style },
            set: { _ in controller.apply(style) }
        ))
        .disabled(!isEditing)
    }
}

// MARK: - Document

private struct DocumentToolbarItems: CustomizableToolbarContent {

    var controller: EditorController
    @Binding var mode: WorkspaceMode
    @Binding var showInspector: Bool
    @Binding var focusMode: Bool
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

        ToolbarItem(id: ToolbarID.viewMode, showsByDefault: true) {
            Menu {
                ForEach(WorkspaceMode.allCases) { item in
                    Toggle(isOn: Binding(get: { mode == item }, set: { _ in mode = item })) {
                        Label(item.title, systemImage: item.symbolName)
                    }
                }
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
    }
}

// MARK: - Shared

/// One toolbar button.
///
/// A `Label` rather than a bare `Image`, so the item has a name in the
/// customisation sheet and a usable entry in the overflow menu.
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
