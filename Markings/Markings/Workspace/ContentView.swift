//
//  ContentView.swift
//  Markings
//
//  Created by Giovanni Di Nisio on 23/08/2026.
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A document window: an outline on the left, the document in the middle, and
/// what is in it on the right.
struct ContentView: View {

    @Binding var document: MarkingsDocument

    @Environment(\.documentConfiguration) private var documentConfiguration

    // Preferences
    @AppStorage(SettingsKey.editorFontFamily) private var editorFontFamily = SettingsDefault.editorFontFamily
    @AppStorage(SettingsKey.editorFontSize) private var editorFontSize = SettingsDefault.editorFontSize
    @AppStorage(SettingsKey.lineHeight) private var lineHeight = SettingsDefault.lineHeight
    @AppStorage(SettingsKey.measure) private var measure = SettingsDefault.measure
    @AppStorage(SettingsKey.focusMode) private var focusMode = SettingsDefault.focusMode
    @AppStorage(SettingsKey.syntaxVisibility) private var syntaxVisibility = SettingsDefault.syntaxVisibility
    @AppStorage(SettingsKey.smartLists) private var smartLists = SettingsDefault.smartLists
    @AppStorage(SettingsKey.wrapSelection) private var wrapSelection = SettingsDefault.wrapSelection
    @AppStorage(SettingsKey.smartLinkPaste) private var smartLinkPaste = SettingsDefault.smartLinkPaste
    @AppStorage(SettingsKey.spellChecking) private var spellChecking = SettingsDefault.spellChecking
    @AppStorage(SettingsKey.indentWidth) private var indentWidth = SettingsDefault.indentWidth
    @AppStorage(SettingsKey.previewFontFamily) private var previewFontFamily = SettingsDefault.previewFontFamily
    @AppStorage(SettingsKey.previewFontSize) private var previewFontSize = SettingsDefault.previewFontSize
    @AppStorage(SettingsKey.syncScrolling) private var syncScrolling = SettingsDefault.syncScrolling
    @AppStorage(SettingsKey.showStatusBar) private var showStatusBar = SettingsDefault.showStatusBar

    // Per-window state, restored with the window.
    @SceneStorage("workspace.mode") private var mode: WorkspaceMode = .split
    @SceneStorage("workspace.outline") private var showOutline = false
    @SceneStorage("workspace.inspector") private var showInspector = false

    @State private var controller = EditorController()
    @State private var blocks: [MarkdownBlock] = []
    @State private var outline: [OutlineItem] = []
    @State private var statistics = DocumentStatistics()
    @State private var previewTarget: Int?
    @State private var exportRequested = false
    @State private var goingToHeading = false
    @State private var isExporting = false
    @State private var exportDocument: HTMLExportDocument?
    @State private var exportFailure: String?

    var body: some View {
        NavigationSplitView(columnVisibility: outlineVisibility) {
            OutlineSidebar(items: outline, currentLine: controller.caretLine) { item in
                reveal(line: item.line)
            }
        } detail: {
            // The toolbar belongs to the detail view, not to the split view.
            // Items declared on the split view are assigned to its leading
            // section — as wide as the sidebar — and every one of them
            // overflows into a chevron.
            detail
                .toolbar(id: ToolbarID.toolbar) {
                    WorkspaceToolbar(controller: controller,
                                     mode: $mode,
                                     showInspector: $showInspector,
                                     focusMode: $focusMode,
                                     exportRequested: $exportRequested,
                                     isEditing: mode != .preview)
                }
        }
        .inspector(isPresented: $showInspector) {
            DocumentInspector(statistics: statistics,
                              fileURL: documentConfiguration?.fileURL)
                .inspectorColumnWidth(min: 240, ideal: 280, max: 380)
        }
        .focusedSceneValue(\.editorController, controller)
        .focusedSceneValue(\.workspaceMode, $mode)
        .focusedSceneValue(\.inspectorVisible, $showInspector)
        .focusedSceneValue(\.htmlExportRequested, $exportRequested)
        .focusedSceneValue(\.goToHeadingRequested, $goingToHeading)
        .sheet(isPresented: $goingToHeading) {
            GoToHeadingSheet(items: outline) { item in
                reveal(line: item.line)
            }
        }
        .task(id: document.text) {
            await reparse()
        }
        .onChange(of: controller.caretLine) { _, line in
            followCaret(to: line)
        }
        .onChange(of: exportRequested) { _, requested in
            guard requested else { return }
            exportRequested = false
            exportDocument = HTMLExportDocument(
                html: MarkdownHTMLExporter.document(title: documentName, blocks: blocks))
            isExporting = true
        }
        .fileExporter(isPresented: $isExporting,
                      document: exportDocument,
                      contentType: .html,
                      defaultFilename: documentName) { result in
            if case .failure(let error) = result {
                exportFailure = error.localizedDescription
            }
        }
        .alert("Couldn’t Export", isPresented: exportFailureBinding) {
            Button("OK", role: .cancel) { exportFailure = nil }
        } message: {
            Text(exportFailure ?? "")
        }
    }

    // MARK: - Panes

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 0) {
            switch mode {
            case .edit:
                editorPane
            case .preview:
                previewPane
            case .split:
                HSplitView {
                    editorPane.frame(minWidth: 300)
                    previewPane.frame(minWidth: 300)
                }
            }

            if showStatusBar {
                EditorStatusBar(statistics: statistics,
                                path: DocumentOutline.path(to: controller.caretLine, in: outline),
                                caretLine: controller.caretLine,
                                caretColumn: controller.caretColumn,
                                showsCaretPosition: mode != .preview) { item in
                    reveal(line: item.line)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var editorPane: some View {
        PageSurface(measure: measure) {
            SourceEditor(text: $document.text,
                         configuration: editorConfiguration,
                         controller: controller)
                .overlay(alignment: .top) { placeholder }
        }
    }

    private var previewPane: some View {
        PageSurface(measure: measure, margin: 32) {
            MarkdownPreview(blocks: blocks,
                            typography: typography,
                            measure: measure,
                            scrollTarget: previewTarget) { line in
                toggleTask(atLine: line)
            }
        }
    }

    /// Sits exactly where the first character will, at any line width.
    @ViewBuilder
    private var placeholder: some View {
        if document.text.isEmpty {
            HStack(spacing: 0) {
                Text("Start writing…")
                    .font(.system(size: CGFloat(editorFontSize), design: editorFontFamily.fontDesign))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
            .padding(.leading, 28)
            .frame(maxWidth: measure.points > 0 ? CGFloat(measure.points) + 56 : .infinity)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 30)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Derived values

    private var editorConfiguration: EditorConfiguration {
        EditorConfiguration(fontFamily: editorFontFamily,
                            fontSize: editorFontSize,
                            lineHeight: lineHeight,
                            measure: measure,
                            focusMode: focusMode,
                            syntaxVisibility: syntaxVisibility,
                            smartLists: smartLists,
                            wrapSelection: wrapSelection,
                            smartLinkPaste: smartLinkPaste,
                            spellChecking: spellChecking,
                            indentWidth: indentWidth)
    }

    private var typography: PreviewTypography {
        PreviewTypography(family: previewFontFamily, baseSize: CGFloat(previewFontSize))
    }

    private var documentName: String {
        guard let url = documentConfiguration?.fileURL else { return "Untitled" }
        return url.deletingPathExtension().lastPathComponent
    }

    private var outlineVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            showOutline ? .all : .detailOnly
        } set: { visibility in
            showOutline = visibility != .detailOnly
        }
    }

    private var exportFailureBinding: Binding<Bool> {
        Binding {
            exportFailure != nil
        } set: { presented in
            if !presented { exportFailure = nil }
        }
    }

    // MARK: - Behaviour

    /// Re-parses after a short pause. Parsing on every keystroke is work the
    /// user never sees; parsing once they stop is work they do.
    private func reparse() async {
        if !blocks.isEmpty {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
        }
        let parsed = MarkdownParser.parse(document.text)
        blocks = parsed
        outline = DocumentOutline.items(from: parsed)
        statistics = DocumentStatistics.make(source: document.text, blocks: parsed)
    }

    private func followCaret(to line: Int) {
        guard syncScrolling, mode == .split else { return }
        let target = blockID(containing: line)
        if target != previewTarget { previewTarget = target }
    }

    private func reveal(line: Int) {
        if mode != .preview { controller.reveal(line: line) }
        previewTarget = blockID(containing: line)
    }

    private func toggleTask(atLine line: Int) {
        if controller.toggleTask(atLine: line) { return }
        // In Preview view there is no text view to edit through, so the change
        // goes straight to the document.
        if let updated = MarkdownTransforms.toggleTask(atLine: line, in: document.text) {
            document.text = updated
        }
    }

    /// The top-level block a source line belongs to — the preview's scroll anchor.
    private func blockID(containing line: Int) -> Int? {
        var candidate: Int?
        for block in blocks {
            if block.firstLine <= line {
                candidate = block.id
            } else {
                break
            }
        }
        return candidate
    }
}

#Preview {
    ContentView(document: .constant(MarkingsDocument(text: """
        # Markings

        A **sleek**, native Markdown reader and editor for macOS.

        - Live syntax highlighting
        - A reading view that follows the caret
        - [x] Task lists you can tick off
        """)))
}
