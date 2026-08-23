//
//  SourceEditor.swift
//  Markings
//

import AppKit
import SwiftUI

/// `NSTextView` with the handful of behaviours a Markdown editor needs that the
/// stock view does not provide.
final class MarkingsTextView: NSTextView {

    var smartLinkPaste = true

    /// Pasting a URL over selected text makes a link out of it — the same
    /// courtesy Notes and Mail extend — and every other paste stays plain,
    /// because pasted styling has no meaning in a plain-text source file.
    override func paste(_ sender: Any?) {
        let range = selectedRange()
        if smartLinkPaste,
           range.length > 0,
           let pasted = NSPasteboard.general.string(forType: .string)?
               .trimmingCharacters(in: .whitespacesAndNewlines),
           MarkdownTransforms.looksLikeURL(pasted) {
            let selected = (string as NSString).substring(with: range)
            let replacement = "[\(selected)](\(pasted))"
            if shouldChangeText(in: range, replacementString: replacement) {
                textStorage?.replaceCharacters(in: range, with: replacement)
                didChangeText()
                setSelectedRange(NSRange(location: range.location + replacement.utf16.count, length: 0))
            }
            return
        }
        pasteAsPlainText(sender)
    }
}

/// The Markdown source editor.
///
/// SwiftUI's `TextEditor` cannot express syntax highlighting, list
/// continuation, or a formatting command that has to know where the selection
/// is — so this wraps `NSTextView`, which is itself the native macOS text
/// editing control, rather than rebuilding text editing from scratch.
struct SourceEditor: NSViewRepresentable {

    @Binding var text: String
    var configuration: EditorConfiguration
    var controller: EditorController

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.postsFrameChangedNotifications = true

        // An explicit TextKit 1 stack: the editor leans on the layout manager
        // for measuring and scrolling, and on the find bar for Find & Replace.
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: CGSize(width: 0, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = MarkingsTextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = CGSize(width: 0, height: 0)
        textView.maxSize = CGSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainerInset = CGSize(width: 28, height: 28)

        // Markdown is source. Substitutions that help in prose corrupt it:
        // smart quotes break code spans and en dashes break thematic breaks.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = configuration.spellChecking
        textView.smartLinkPaste = configuration.smartLinkPaste
        textView.typingAttributes = context.coordinator.highlighter.baseAttributes

        scrollView.documentView = textView
        context.coordinator.install(textView: textView, scrollView: scrollView)

        controller.attach(textView)
        controller.indentWidth = configuration.indentWidth

        textView.string = text
        context.coordinator.highlightNow()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkingsTextView else { return }
        let coordinator = context.coordinator
        coordinator.parent = self
        controller.indentWidth = configuration.indentWidth

        if coordinator.configuration != configuration {
            coordinator.configuration = configuration
            coordinator.highlighter = MarkdownSyntaxHighlighter(configuration: configuration)
            textView.isContinuousSpellCheckingEnabled = configuration.spellChecking
            textView.smartLinkPaste = configuration.smartLinkPaste
            textView.typingAttributes = coordinator.highlighter.baseAttributes
            coordinator.updateInsets()
            coordinator.highlightNow()
        }

        // Only replace the text when it genuinely differs, so ordinary typing
        // never resets the selection or the undo stack.
        if textView.string != text {
            coordinator.isSyncingFromDocument = true
            let previous = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(previous.location, length), length: 0))
            coordinator.isSyncingFromDocument = false
            coordinator.highlightNow()
            coordinator.scheduleStateRefresh()
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {

        var parent: SourceEditor
        var configuration: EditorConfiguration
        var highlighter: MarkdownSyntaxHighlighter
        var isSyncingFromDocument = false

        private weak var textView: MarkingsTextView?
        private weak var scrollView: NSScrollView?
        private var isApplyingCompoundEdit = false
        private var highlightTask: Task<Void, Never>?

        /// Typing one of these over a selection wraps the selection instead of
        /// replacing it — the single most useful shortcut in a Markdown editor.
        private static let wrappingPairs: [String: (opening: String, closing: String)] = [
            "*": ("*", "*"),
            "_": ("_", "_"),
            "`": ("`", "`"),
            "~": ("~", "~"),
            "\"": ("\"", "\""),
            "(": ("(", ")"),
            "[": ("[", "]"),
            "{": ("{", "}")
        ]

        init(_ parent: SourceEditor) {
            self.parent = parent
            self.configuration = parent.configuration
            self.highlighter = MarkdownSyntaxHighlighter(configuration: parent.configuration)
            super.init()
        }

        func install(textView: MarkingsTextView, scrollView: NSScrollView) {
            self.textView = textView
            self.scrollView = scrollView
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(frameDidChange(_:)),
                                                   name: NSView.frameDidChangeNotification,
                                                   object: scrollView)
            updateInsets()
        }

        func uninstall() {
            highlightTask?.cancel()
            NotificationCenter.default.removeObserver(self)
            if let textView { parent.controller.detach(textView) }
            textView = nil
            scrollView = nil
        }

        @objc private func frameDidChange(_ notification: Notification) {
            updateInsets()
        }

        /// Centres the text column at the chosen measure. Line length is a
        /// readability decision, not a window-size accident.
        func updateInsets() {
            guard let textView, let scrollView else { return }
            let available = scrollView.contentSize.width
            guard available > 0 else { return }
            let measure = CGFloat(configuration.measure.points)
            let horizontal = measure > 0 ? max(28, (available - measure) / 2) : 28
            if abs(textView.textContainerInset.width - horizontal) > 0.5 {
                textView.textContainerInset = CGSize(width: horizontal, height: 28)
            }
        }

        // MARK: Highlighting

        func highlightNow() {
            highlightTask?.cancel()
            guard let textView, let storage = textView.textStorage else { return }
            let focus = configuration.focusMode ? textView.selectedRange().location : nil
            highlighter.highlight(storage, focusLocation: focus)
        }

        /// Coalesces bursts of typing into one highlighting pass.
        func scheduleHighlight() {
            highlightTask?.cancel()
            highlightTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(30))
                guard let self, !Task.isCancelled else { return }
                self.highlightNow()
            }
        }

        /// Publishes caret state after the current view update, never during it.
        func scheduleStateRefresh() {
            Task { [weak self] in
                self?.parent.controller.refreshState()
            }
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView, !isSyncingFromDocument else { return }
            parent.text = textView.string
            scheduleHighlight()
            scheduleStateRefresh()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isSyncingFromDocument else { return }
            scheduleStateRefresh()
            if configuration.focusMode { scheduleHighlight() }
        }

        func textView(_ textView: NSTextView,
                      shouldChangeTextIn affectedCharRange: NSRange,
                      replacementString: String?) -> Bool {
            guard !isApplyingCompoundEdit else { return true }
            guard configuration.wrapSelection,
                  affectedCharRange.length > 0,
                  let replacementString,
                  let pair = Self.wrappingPairs[replacementString] else { return true }

            let edit = MarkdownTransforms.wrap(opening: pair.opening,
                                               closing: pair.closing,
                                               in: textView.string as NSString,
                                               selection: affectedCharRange)
            isApplyingCompoundEdit = true
            defer { isApplyingCompoundEdit = false }
            parent.controller.apply(edit)
            return false
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                guard configuration.smartLists else { return false }
                guard let edit = MarkdownTransforms.newlineContinuation(
                    in: textView.string as NSString,
                    selection: textView.selectedRange()) else { return false }
                return parent.controller.apply(edit)

            case #selector(NSResponder.insertTab(_:)):
                guard shouldHandleTab(in: textView) else { return false }
                parent.controller.indent()
                return true

            case #selector(NSResponder.insertBacktab(_:)):
                parent.controller.outdent()
                return true

            default:
                return false
            }
        }

        /// Tab only re-indents where indentation means something; everywhere
        /// else it stays a tab character, as the rest of macOS expects.
        private func shouldHandleTab(in textView: NSTextView) -> Bool {
            let selection = textView.selectedRange()
            if selection.length > 0 { return true }
            let text = textView.string as NSString
            let lineRange = MarkdownTransforms.lineRange(in: text, for: selection)
            return MarkdownLine.parse(text.substring(with: lineRange)).isListItem
        }
    }
}
