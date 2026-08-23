//
//  AppSettings.swift
//  Markings
//

import Foundation
import SwiftUI

/// Typeface choices offered for the editor and the reading view.
nonisolated enum MarkingsFontFamily: String, CaseIterable, Identifiable {
    case sansSerif
    case serif
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sansSerif: return "Sans Serif"
        case .serif: return "Serif"
        case .monospaced: return "Monospaced"
        }
    }

    var subtitle: String {
        switch self {
        case .sansSerif: return "San Francisco — the system typeface"
        case .serif: return "New York — comfortable for long reading"
        case .monospaced: return "SF Mono — every character the same width"
        }
    }
}

/// How wide the text column is allowed to grow.
nonisolated enum MarkingsMeasure: String, CaseIterable, Identifiable {
    case narrow
    case comfortable
    case wide
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .narrow: return "Narrow"
        case .comfortable: return "Comfortable"
        case .wide: return "Wide"
        case .full: return "Full Width"
        }
    }

    /// Points, or zero to fill the available width.
    var points: Double {
        switch self {
        case .narrow: return 560
        case .comfortable: return 720
        case .wide: return 900
        case .full: return 0
        }
    }
}

/// How the workspace is split between writing and reading.
nonisolated enum WorkspaceMode: String, CaseIterable, Identifiable {
    case edit
    case split
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: return "Edit"
        case .split: return "Split"
        case .preview: return "Preview"
        }
    }

    var symbolName: String {
        switch self {
        case .edit: return "pencil"
        case .split: return "rectangle.split.2x1"
        case .preview: return "eye"
        }
    }

    var help: String {
        switch self {
        case .edit: return "Show the Markdown source only"
        case .split: return "Show the source and the reading view side by side"
        case .preview: return "Show the reading view only"
        }
    }
}

/// `UserDefaults` keys, in one place so a preference can never drift between
/// the view that writes it and the view that reads it.
nonisolated enum SettingsKey {
    static let editorFontFamily = "editor.fontFamily"
    static let editorFontSize = "editor.fontSize"
    static let lineHeight = "editor.lineHeight"
    static let measure = "editor.measure"
    static let focusMode = "editor.focusMode"
    static let smartLists = "editor.smartLists"
    static let wrapSelection = "editor.wrapSelection"
    static let smartLinkPaste = "editor.smartLinkPaste"
    static let spellChecking = "editor.spellChecking"
    static let indentWidth = "editor.indentWidth"
    static let previewFontFamily = "preview.fontFamily"
    static let previewFontSize = "preview.fontSize"
    static let syncScrolling = "workspace.syncScrolling"
    static let showStatusBar = "workspace.showStatusBar"
}

nonisolated enum SettingsDefault {
    static let editorFontFamily = MarkingsFontFamily.sansSerif
    static let editorFontSize = 15.0
    static let lineHeight = 1.45
    static let measure = MarkingsMeasure.comfortable
    static let focusMode = false
    static let smartLists = true
    static let wrapSelection = true
    static let smartLinkPaste = true
    static let spellChecking = true
    static let indentWidth = 2
    static let previewFontFamily = MarkingsFontFamily.sansSerif
    static let previewFontSize = 16.0
    static let syncScrolling = true
    static let showStatusBar = true
}

/// Everything the source editor needs to know about the user's preferences.
///
/// Passing one value instead of a dozen bindings keeps `updateNSView` able to
/// answer "did anything actually change?" with a single comparison.
nonisolated struct EditorConfiguration: Equatable {
    var fontFamily: MarkingsFontFamily = SettingsDefault.editorFontFamily
    var fontSize: Double = SettingsDefault.editorFontSize
    var lineHeight: Double = SettingsDefault.lineHeight
    var measure: MarkingsMeasure = SettingsDefault.measure
    var focusMode: Bool = SettingsDefault.focusMode
    var smartLists: Bool = SettingsDefault.smartLists
    var wrapSelection: Bool = SettingsDefault.wrapSelection
    var smartLinkPaste: Bool = SettingsDefault.smartLinkPaste
    var spellChecking: Bool = SettingsDefault.spellChecking
    var indentWidth: Int = SettingsDefault.indentWidth
}
