//
//  MarkingsCommands.swift
//  Markings
//

import AppKit
import SwiftUI

/// The menu bar.
///
/// On macOS the menu bar — not the toolbar — is where the full set of commands
/// lives, where keyboard shortcuts are discovered, and where anything a user
/// cannot find in the interface is still reachable. Every formatting action in
/// Markings appears here, whether or not it also has a toolbar button.
struct MarkingsCommands: Commands {

    @FocusedValue(\.editorController) private var controller: EditorController?
    @FocusedBinding(\.workspaceMode) private var mode: WorkspaceMode?
    @FocusedBinding(\.inspectorVisible) private var inspectorVisible: Bool?
    @FocusedBinding(\.htmlExportRequested) private var exportRequested: Bool?

    @AppStorage(SettingsKey.focusMode) private var focusMode = SettingsDefault.focusMode
    @AppStorage(SettingsKey.editorFontSize) private var editorFontSize = SettingsDefault.editorFontSize
    @AppStorage(SettingsKey.previewFontSize) private var previewFontSize = SettingsDefault.previewFontSize
    @AppStorage(SettingsKey.showStatusBar) private var showStatusBar = SettingsDefault.showStatusBar

    private var hasEditor: Bool { controller != nil }

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Export as HTML…") { exportRequested = true }
                .disabled(exportRequested == nil)
        }

        CommandGroup(after: .textEditing) {
            Divider()
            findMenu
        }

        CommandMenu("Format") {
            inlineCommands
            Divider()
            paragraphCommands
            Divider()
            listCommands
            Divider()
            insertCommands
            Divider()
            indentCommands
        }

        CommandGroup(after: .toolbar) {
            viewModeCommands
            Divider()
            layoutCommands
            Divider()
            textSizeCommands
        }
    }

    // MARK: - Edit ▸ Find

    private var findMenu: some View {
        Menu("Find") {
            Button("Find…") { controller?.performFindAction(.showFindInterface) }
                .keyboardShortcut("f")
            Button("Find and Replace…") { controller?.performFindAction(.showReplaceInterface) }
                .keyboardShortcut("f", modifiers: [.command, .option])
            Divider()
            Button("Find Next") { controller?.performFindAction(.nextMatch) }
                .keyboardShortcut("g")
            Button("Find Previous") { controller?.performFindAction(.previousMatch) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("Use Selection for Find") { controller?.performFindAction(.setSearchString) }
                .keyboardShortcut("e")
        }
        .disabled(!hasEditor)
    }

    // MARK: - Format

    private var inlineCommands: some View {
        Group {
            Button("Bold") { controller?.toggleBold() }
                .keyboardShortcut("b")
            Button("Italic") { controller?.toggleItalic() }
                .keyboardShortcut("i")
            Button("Strikethrough") { controller?.toggleStrikethrough() }
                .keyboardShortcut("x", modifiers: [.command, .shift])
            Button("Inline Code") { controller?.toggleInlineCode() }
                .keyboardShortcut("c", modifiers: [.command, .control])
            Button("Highlight") { controller?.toggleHighlight() }
                .keyboardShortcut("h", modifiers: [.command, .control])
            Divider()
            Button("Link…") { controller?.insertLink() }
                .keyboardShortcut("k")
            Button("Image…") { controller?.insertImage() }
                .keyboardShortcut("i", modifiers: [.command, .control])
        }
        .disabled(!hasEditor)
    }

    private var paragraphCommands: some View {
        Group {
            Button("Body") { controller?.setBody() }
                .keyboardShortcut("0", modifiers: [.command, .option])
            Menu("Heading") {
                ForEach(1...6, id: \.self) { level in
                    Button("Heading \(level)") { controller?.setHeading(level: level) }
                        .keyboardShortcut(KeyEquivalent(Character("\(level)")), modifiers: [.command, .option])
                }
            }
        }
        .disabled(!hasEditor)
    }

    private var listCommands: some View {
        Group {
            Button("Bulleted List") { controller?.toggleBulletList() }
                .keyboardShortcut("7", modifiers: [.command, .shift])
            Button("Numbered List") { controller?.toggleNumberedList() }
                .keyboardShortcut("8", modifiers: [.command, .shift])
            Button("Task List") { controller?.toggleTaskList() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Block Quote") { controller?.toggleBlockQuote() }
                .keyboardShortcut("b", modifiers: [.command, .option])
            Divider()
            Button("Mark Task as Done") { controller?.toggleTaskCompletion() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
        }
        .disabled(!hasEditor)
    }

    private var insertCommands: some View {
        Group {
            Button("Code Block") { controller?.insertCodeBlock() }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button("Table") { controller?.insertTable() }
                .keyboardShortcut("t", modifiers: [.command, .control])
            Button("Divider") { controller?.insertThematicBreak() }
                .keyboardShortcut("-", modifiers: [.command, .shift])
        }
        .disabled(!hasEditor)
    }

    private var indentCommands: some View {
        Group {
            Button("Increase Indent") { controller?.indent() }
                .keyboardShortcut("]")
            Button("Decrease Indent") { controller?.outdent() }
                .keyboardShortcut("[")
        }
        .disabled(!hasEditor)
    }

    // MARK: - View

    private var viewModeCommands: some View {
        Group {
            Button("Editor") { mode = .edit }
                .keyboardShortcut("1")
            Button("Split") { mode = .split }
                .keyboardShortcut("2")
            Button("Preview") { mode = .preview }
                .keyboardShortcut("3")
        }
        .disabled(mode == nil)
    }

    private var layoutCommands: some View {
        Group {
            Button((inspectorVisible ?? false) ? "Hide Document Info" : "Show Document Info") {
                inspectorVisible?.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(inspectorVisible == nil)

            Toggle("Focus Mode", isOn: $focusMode)
                .keyboardShortcut("f", modifiers: [.command, .shift])

            Toggle("Show Word Count", isOn: $showStatusBar)
        }
    }

    private var textSizeCommands: some View {
        Group {
            Button("Increase Text Size") { changeTextSize(by: 1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Decrease Text Size") { changeTextSize(by: -1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") {
                editorFontSize = SettingsDefault.editorFontSize
                previewFontSize = SettingsDefault.previewFontSize
            }
            .keyboardShortcut("0")
        }
    }

    private func changeTextSize(by delta: Double) {
        editorFontSize = min(max(editorFontSize + delta, 10), 32)
        previewFontSize = min(max(previewFontSize + delta, 11), 34)
    }
}
