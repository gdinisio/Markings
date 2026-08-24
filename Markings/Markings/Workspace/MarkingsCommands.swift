//
//  MarkingsCommands.swift
//  Markings
//

import AppKit
import Foundation
import SwiftUI

/// The menu bar.
///
/// On macOS the menu bar — not the toolbar — is the complete index of what an
/// app can do. Everything Markings can do to a document is here, grouped where
/// a person would look for it: Format for how text reads, Insert for things
/// added to it, Edit for moving it around, View for how it is shown.
///
/// Items are disabled rather than hidden when no document has focus, so the
/// shape of the app stays the same whatever is in front.
struct MarkingsCommands: Commands {

    @Environment(\.openWindow) private var openWindow

    @FocusedValue(\.editorController) private var controller: EditorController?
    @FocusedBinding(\.workspaceMode) private var mode: WorkspaceMode?
    @FocusedBinding(\.inspectorVisible) private var inspectorVisible: Bool?
    @FocusedBinding(\.htmlExportRequested) private var exportRequested: Bool?

    @AppStorage(SettingsKey.focusMode) private var focusMode = SettingsDefault.focusMode
    @AppStorage(SettingsKey.syntaxVisibility) private var syntaxVisibility = SettingsDefault.syntaxVisibility
    @AppStorage(SettingsKey.syncScrolling) private var syncScrolling = SettingsDefault.syncScrolling
    @AppStorage(SettingsKey.showStatusBar) private var showStatusBar = SettingsDefault.showStatusBar
    @AppStorage(SettingsKey.editorFontSize) private var editorFontSize = SettingsDefault.editorFontSize
    @AppStorage(SettingsKey.previewFontSize) private var previewFontSize = SettingsDefault.previewFontSize

    private var hasEditor: Bool { controller != nil }

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Export as HTML…") { exportRequested = true }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(exportRequested == nil)
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            copyAsCommands
        }

        CommandGroup(after: .textEditing) {
            Divider()
            lineCommands
            Divider()
            findMenu
        }

        CommandMenu("Format") {
            inlineCommands
            Divider()
            headingCommands
            Divider()
            listCommands
            Divider()
            indentCommands
        }

        CommandMenu("Insert") {
            insertCommands
        }

        CommandGroup(after: .toolbar) {
            Divider()
            viewModeCommands
            Divider()
            layoutCommands
            Divider()
            textSizeCommands
        }

        CommandGroup(before: .windowList) {
            Button("Welcome to Markings") { openWindow(id: WindowID.welcome) }
            Divider()
        }

        CommandGroup(replacing: .help) {
            Button("Markdown Syntax") { openWindow(id: WindowID.syntaxReference) }
                .keyboardShortcut("/", modifiers: [.command, .shift])
        }
    }

    // MARK: - Edit

    private var copyAsCommands: some View {
        Group {
            Button("Copy as HTML") { controller?.copyAsHTML() }
            Button("Copy as Plain Text") { controller?.copyAsPlainText() }
        }
        .disabled(!hasEditor)
    }

    private var lineCommands: some View {
        Group {
            Button("Move Line Up") { controller?.moveLinesUp() }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Move Line Down") { controller?.moveLinesDown() }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
        }
        .disabled(!hasEditor)
    }

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
        }
        .disabled(!hasEditor)
    }

    private var headingCommands: some View {
        Group {
            Button("Body") { controller?.setBody() }
                .keyboardShortcut("0", modifiers: [.command, .option])
            Menu("Heading") {
                ForEach(1...6, id: \.self) { level in
                    Button("Heading \(level)") { controller?.setHeading(level: level) }
                        .keyboardShortcut(KeyEquivalent(Character("\(level)")), modifiers: [.command, .option])
                }
            }
            Button("Raise Heading Level") { controller?.raiseHeadingLevel() }
                .keyboardShortcut(.upArrow, modifiers: [.command, .control])
            Button("Lower Heading Level") { controller?.lowerHeadingLevel() }
                .keyboardShortcut(.downArrow, modifiers: [.command, .control])
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

    private var indentCommands: some View {
        Group {
            Button("Increase Indent") { controller?.indent() }
                .keyboardShortcut("]")
            Button("Decrease Indent") { controller?.outdent() }
                .keyboardShortcut("[")
        }
        .disabled(!hasEditor)
    }

    // MARK: - Insert

    private var insertCommands: some View {
        Group {
            Button("Link…") { controller?.insertLink() }
                .keyboardShortcut("k")
            Button("Image…") { controller?.insertImage() }
                .keyboardShortcut("i", modifiers: [.command, .control])
            Divider()
            Button("Table") { controller?.insertTable() }
                .keyboardShortcut("t", modifiers: [.command, .control])
            Button("Code Block") { controller?.insertCodeBlock() }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button("Divider") { controller?.insertThematicBreak() }
                .keyboardShortcut("-", modifiers: [.command, .shift])
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

            Toggle("Always Show Markdown Syntax", isOn: alwaysShowSyntax)
            Toggle("Focus Mode", isOn: $focusMode)
                .keyboardShortcut("f", modifiers: [.command, .shift])
            Toggle("Follow the Caret in Split View", isOn: $syncScrolling)
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

    /// The setting is a choice of two, but in a menu it reads better as
    /// something you switch on than as a list you pick from.
    private var alwaysShowSyntax: Binding<Bool> {
        Binding {
            syntaxVisibility == .always
        } set: { always in
            syntaxVisibility = always ? .always : .currentLine
        }
    }

    private func changeTextSize(by delta: Double) {
        editorFontSize = min(max(editorFontSize + delta, 10), 32)
        previewFontSize = min(max(previewFontSize + delta, 11), 34)
    }
}
