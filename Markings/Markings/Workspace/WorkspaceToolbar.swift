//
//  WorkspaceToolbar.swift
//  Markings
//

import Foundation
import SwiftUI

/// The document window's toolbar: the formatting people reach for constantly,
/// with everything else one menu away.
///
/// The paragraph-style control is a pop-up rather than a row of buttons because
/// it also has to *report* the style of the current line, not only set it.
struct WorkspaceToolbar: ToolbarContent {

    var controller: EditorController
    @Binding var mode: WorkspaceMode
    @Binding var showInspector: Bool
    var isEditing: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            paragraphStyle
        }

        ToolbarItem(placement: .automatic) {
            ControlGroup {
                button("Bold", "bold") { controller.toggleBold() }
                button("Italic", "italic") { controller.toggleItalic() }
                button("Strikethrough", "strikethrough") { controller.toggleStrikethrough() }
                button("Inline Code", "chevron.left.forwardslash.chevron.right") { controller.toggleInlineCode() }
            }
            .disabled(!isEditing)
        }

        ToolbarItem(placement: .automatic) {
            ControlGroup {
                button("Bulleted List", "list.bullet") { controller.toggleBulletList() }
                button("Numbered List", "list.number") { controller.toggleNumberedList() }
                button("Task List", "checklist") { controller.toggleTaskList() }
                button("Block Quote", "text.quote") { controller.toggleBlockQuote() }
            }
            .disabled(!isEditing)
        }

        ToolbarItem(placement: .automatic) {
            insertMenu
        }

        ToolbarItem(placement: .primaryAction) {
            viewModePicker
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showInspector.toggle()
            } label: {
                Label("Document Info", systemImage: "sidebar.right")
            }
            .help("Show or hide document information")
        }
    }

    // MARK: - Pieces

    private var paragraphStyle: some View {
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
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 146)
        .disabled(!isEditing)
        .help("Paragraph style of the current line")
    }

    /// Reads the caret's current style and applies a new one — so the control
    /// both answers "what is this?" and changes it.
    private var styleSelection: Binding<BlockStyle> {
        Binding {
            controller.blockStyle
        } set: { style in
            controller.apply(style)
        }
    }

    private var insertMenu: some View {
        Menu {
            Button { controller.insertLink() } label: { Label("Link", systemImage: "link") }
            Button { controller.insertImage() } label: { Label("Image", systemImage: "photo") }
            Divider()
            Button { controller.insertTable() } label: { Label("Table", systemImage: "tablecells") }
            Button { controller.insertCodeBlock() } label: { Label("Code Block", systemImage: "curlybraces") }
            Button { controller.insertThematicBreak() } label: { Label("Divider", systemImage: "minus") }
            Divider()
            Button { controller.toggleHighlight() } label: { Label("Highlight", systemImage: "highlighter") }
        } label: {
            Label("Insert", systemImage: "plus")
        }
        .disabled(!isEditing)
        .help("Insert a link, image, table, code block or divider")
    }

    private var viewModePicker: some View {
        Picker("View", selection: $mode) {
            ForEach(WorkspaceMode.allCases) { item in
                Label(item.title, systemImage: item.symbolName)
                    .labelStyle(.iconOnly)
                    .tag(item)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .help("Show the source, the reading view, or both")
    }

    private func button(_ title: String,
                        _ symbol: String,
                        action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Label(title, systemImage: symbol)
        }
        .help(title)
    }
}
