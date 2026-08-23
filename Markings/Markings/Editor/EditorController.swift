//
//  EditorController.swift
//  Markings
//

import AppKit
import Foundation
import Observation

/// The bridge between SwiftUI commands and the text view that owns the text.
///
/// The toolbar, the menu bar and the outline all talk to the document through
/// this one object, which means every route to a given change performs exactly
/// the same edit — and lands in the same undo group.
@Observable
final class EditorController: Equatable {

    /// Deliberately not observed: the view reference is plumbing, and observing
    /// it would invalidate the toolbar every time a window is rebuilt.
    @ObservationIgnored weak var textView: NSTextView?
    @ObservationIgnored var indentWidth: Int = SettingsDefault.indentWidth

    private(set) var selectedRange = NSRange(location: 0, length: 0)
    private(set) var caretLine = 0
    private(set) var caretColumn = 1
    private(set) var blockStyle: BlockStyle = .body
    private(set) var hasSelection = false

    nonisolated static func == (lhs: EditorController, rhs: EditorController) -> Bool {
        lhs === rhs
    }

    // MARK: - Attachment

    func attach(_ textView: NSTextView) {
        self.textView = textView
    }

    func detach(_ textView: NSTextView) {
        if self.textView === textView { self.textView = nil }
    }

    /// Refreshes the caret read-outs the toolbar and status bar display.
    func refreshState() {
        guard let textView else { return }
        let text = textView.string as NSString
        let range = textView.selectedRange()
        selectedRange = range
        hasSelection = range.length > 0
        caretLine = MarkdownTransforms.lineNumber(in: text, at: range.location)
        caretColumn = MarkdownTransforms.column(in: text, at: range.location)
        blockStyle = MarkdownTransforms.blockStyle(in: text, at: range)
    }

    func focusEditor() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    // MARK: - Applying edits

    /// Routes an edit through `NSTextView` rather than the text storage alone,
    /// which is what registers undo and notifies accessibility.
    @discardableResult
    func apply(_ edit: TextEdit) -> Bool {
        guard let textView, let storage = textView.textStorage else { return false }
        guard textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return false }
        storage.replaceCharacters(in: edit.range, with: edit.replacement)
        textView.didChangeText()

        let length = (textView.string as NSString).length
        let location = min(max(edit.selection.location, 0), length)
        let selectionLength = min(max(edit.selection.length, 0), length - location)
        textView.setSelectedRange(NSRange(location: location, length: selectionLength))
        textView.scrollRangeToVisible(textView.selectedRange())
        return true
    }

    private func perform(_ transform: (NSString, NSRange) -> TextEdit?) {
        guard let textView else { return }
        let text = textView.string as NSString
        guard let edit = transform(text, textView.selectedRange()) else { return }
        apply(edit)
    }

    // MARK: - Inline formatting

    func toggleBold() { toggleInline("**") }
    func toggleItalic() { toggleInline("*") }
    func toggleStrikethrough() { toggleInline("~~") }
    func toggleInlineCode() { toggleInline("`") }
    func toggleHighlight() { toggleInline("==") }

    private func toggleInline(_ marker: String) {
        perform { MarkdownTransforms.toggleInline(marker: marker, in: $0, selection: $1) }
    }

    func insertLink() {
        perform { MarkdownTransforms.insertLink(isImage: false, in: $0, selection: $1) }
    }

    func insertImage() {
        perform { MarkdownTransforms.insertLink(isImage: true, in: $0, selection: $1) }
    }

    // MARK: - Block formatting

    func apply(_ style: BlockStyle) {
        perform { MarkdownTransforms.apply(style, in: $0, selection: $1) }
    }

    func setHeading(level: Int) { apply(.heading(level)) }
    func setBody() { apply(.body) }
    func toggleBulletList() { apply(.bulletList) }
    func toggleNumberedList() { apply(.numberedList) }
    func toggleTaskList() { apply(.taskList) }
    func toggleBlockQuote() { apply(.quote) }

    func toggleTaskCompletion() {
        perform { MarkdownTransforms.toggleTaskCompletion(in: $0, selection: $1) }
    }

    func indent() {
        perform { MarkdownTransforms.indent(in: $0, selection: $1, tabWidth: self.indentWidth) }
    }

    func outdent() {
        perform { MarkdownTransforms.outdent(in: $0, selection: $1, tabWidth: self.indentWidth) }
    }

    // MARK: - Insertions

    func insertCodeBlock() {
        perform { MarkdownTransforms.insertCodeBlock(in: $0, selection: $1) }
    }

    func insertTable() {
        perform { MarkdownTransforms.insertTable(in: $0, selection: $1) }
    }

    func insertThematicBreak() {
        perform { MarkdownTransforms.insertThematicBreak(in: $0, selection: $1) }
    }

    /// Flips one task item by source line — the path the preview's checkboxes take.
    @discardableResult
    func toggleTask(atLine line: Int) -> Bool {
        guard let textView else { return false }
        let text = textView.string as NSString
        guard let range = MarkdownTransforms.range(ofLine: line, in: text) else { return false }
        var parsed = MarkdownLine.parse(text.substring(with: range))
        guard let checked = parsed.task else { return false }
        parsed.task = !checked
        let selection = textView.selectedRange()
        let handled = apply(TextEdit(range: range, replacement: parsed.composed, selection: selection))
        return handled
    }

    // MARK: - Navigation

    /// Scrolls to a source line and puts the caret on it.
    func reveal(line: Int) {
        guard let textView else { return }
        let text = textView.string as NSString
        guard let range = MarkdownTransforms.range(ofLine: line, in: text) else { return }
        textView.setSelectedRange(NSRange(location: range.location, length: 0))

        if let layoutManager = textView.layoutManager, let container = textView.textContainer {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
            rect.origin.x += textView.textContainerInset.width
            rect.origin.y += textView.textContainerInset.height
            // Grow the target downwards so the heading settles near the top of
            // the view instead of scraping the bottom edge.
            rect.size.height = max(rect.height, textView.visibleRect.height * 0.7)
            textView.scrollToVisible(rect)
        } else {
            textView.scrollRangeToVisible(range)
        }
        focusEditor()
    }

    // MARK: - Find

    func performFindAction(_ action: NSTextFinder.Action) {
        guard let textView else { return }
        let item = NSMenuItem()
        item.tag = action.rawValue
        textView.performTextFinderAction(item)
    }
}
