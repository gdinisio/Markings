//
//  EditorTheme.swift
//  Markings
//

import AppKit
import Foundation

/// The four faces the source editor needs, derived once per configuration.
struct EditorFontSet {
    var regular: NSFont
    var bold: NSFont
    var italic: NSFont
    var boldItalic: NSFont
    var monospaced: NSFont
    /// Applied when the chosen family has no true italic, so emphasis is still
    /// visible rather than silently identical to body text.
    var syntheticObliqueness: CGFloat

    static func make(family: MarkingsFontFamily, size: CGFloat) -> EditorFontSet {
        let regular = base(family: family, size: size, weight: .regular)
        let bold = base(family: family, size: size, weight: .bold)
        let italic = italicVariant(of: regular)
        let boldItalic = italicVariant(of: bold)
        let hasTrueItalic = italic.fontDescriptor.symbolicTraits.contains(.italic)

        return EditorFontSet(regular: regular,
                             bold: bold,
                             italic: italic,
                             boldItalic: boldItalic,
                             monospaced: NSFont.monospacedSystemFont(ofSize: size * 0.95, weight: .regular),
                             syntheticObliqueness: hasTrueItalic ? 0 : 0.18)
    }

    /// A heading face, scaled and weighted by level.
    func heading(level: Int, baseSize: CGFloat) -> NSFont {
        let scales: [CGFloat] = [1.65, 1.42, 1.25, 1.12, 1.05, 1.0]
        let scale = scales[min(max(level, 1), 6) - 1]
        return NSFont(descriptor: bold.fontDescriptor, size: (baseSize * scale).rounded()) ?? bold
    }

    private static func base(family: MarkingsFontFamily, size: CGFloat, weight: NSFont.Weight) -> NSFont {
        switch family {
        case .monospaced:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .sansSerif:
            return NSFont.systemFont(ofSize: size, weight: weight)
        case .serif:
            let system = NSFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = system.fontDescriptor.withDesign(.serif),
                  let font = NSFont(descriptor: descriptor, size: size) else { return system }
            return font
        }
    }

    private static func italicVariant(of font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }
}

/// Semantic colours for the source editor.
///
/// Everything resolves from system colours, so the editor follows the user's
/// appearance and accent colour instead of inventing its own palette.
enum EditorTheme {
    static var text: NSColor { .textColor }
    /// Syntax characters stay legible but recede behind the prose they mark up.
    static var syntax: NSColor { .tertiaryLabelColor }
    /// Markers away from the caret: still there, all but invisible. They keep
    /// their space, so revealing one never shifts the text around it.
    static var fadedSyntax: NSColor { .tertiaryLabelColor.withAlphaComponent(0.28) }
    static var fadedAccent: NSColor { .controlAccentColor.withAlphaComponent(0.35) }
    static var secondaryText: NSColor { .secondaryLabelColor }
    static var accent: NSColor { .controlAccentColor }
    static var link: NSColor { .linkColor }
    static var codeText: NSColor { .secondaryLabelColor }
    static var codeBackground: NSColor { .labelColor.withAlphaComponent(0.05) }
    static var highlightBackground: NSColor { .systemYellow.withAlphaComponent(0.28) }
    static var completedTask: NSColor { .tertiaryLabelColor }
    /// Used by Focus Mode for everything outside the current paragraph.
    static var dimmed: NSColor { .tertiaryLabelColor.withAlphaComponent(0.55) }
}
