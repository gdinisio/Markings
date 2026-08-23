//
//  SettingsView.swift
//  Markings
//

import SwiftUI

/// Settings, in the shape macOS expects: a tabbed window of grouped forms,
/// every change applying immediately with no Apply button to hunt for.
struct SettingsView: View {

    var body: some View {
        TabView {
            EditingSettings()
                .tabItem { Label("Editing", systemImage: "square.and.pencil") }
            ReadingSettings()
                .tabItem { Label("Reading", systemImage: "eye") }
        }
        .frame(width: 520)
    }
}

struct EditingSettings: View {

    @AppStorage(SettingsKey.editorFontFamily) private var fontFamily = SettingsDefault.editorFontFamily
    @AppStorage(SettingsKey.editorFontSize) private var fontSize = SettingsDefault.editorFontSize
    @AppStorage(SettingsKey.lineHeight) private var lineHeight = SettingsDefault.lineHeight
    @AppStorage(SettingsKey.measure) private var measure = SettingsDefault.measure
    @AppStorage(SettingsKey.focusMode) private var focusMode = SettingsDefault.focusMode
    @AppStorage(SettingsKey.smartLists) private var smartLists = SettingsDefault.smartLists
    @AppStorage(SettingsKey.wrapSelection) private var wrapSelection = SettingsDefault.wrapSelection
    @AppStorage(SettingsKey.smartLinkPaste) private var smartLinkPaste = SettingsDefault.smartLinkPaste
    @AppStorage(SettingsKey.spellChecking) private var spellChecking = SettingsDefault.spellChecking
    @AppStorage(SettingsKey.indentWidth) private var indentWidth = SettingsDefault.indentWidth

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Typeface", selection: $fontFamily) {
                    ForEach(MarkingsFontFamily.allCases) { family in
                        Text(family.title).tag(family)
                    }
                }
                LabeledContent("Text size") {
                    HStack {
                        Slider(value: $fontSize, in: 10...28, step: 1)
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent("Line height") {
                    HStack {
                        Slider(value: $lineHeight, in: 1.0...2.2, step: 0.05)
                        Text(lineHeight.formatted(.number.precision(.fractionLength(2))))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Picker("Line width", selection: $measure) {
                    ForEach(MarkingsMeasure.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                Toggle("Focus Mode", isOn: $focusMode)
                Text("Focus Mode dims everything except the paragraph you are writing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Writing") {
                Toggle("Continue lists and quotes on Return", isOn: $smartLists)
                Toggle("Wrap the selection when typing * _ ` or a bracket", isOn: $wrapSelection)
                Toggle("Make a link when pasting a URL over selected text", isOn: $smartLinkPaste)
                Toggle("Check spelling while typing", isOn: $spellChecking)
                Picker("Indent step", selection: $indentWidth) {
                    Text("2 spaces").tag(2)
                    Text("4 spaces").tag(4)
                }
                Text("Nesting a list still lines up with its parent item, whatever the step.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct ReadingSettings: View {

    @AppStorage(SettingsKey.previewFontFamily) private var fontFamily = SettingsDefault.previewFontFamily
    @AppStorage(SettingsKey.previewFontSize) private var fontSize = SettingsDefault.previewFontSize
    @AppStorage(SettingsKey.syncScrolling) private var syncScrolling = SettingsDefault.syncScrolling
    @AppStorage(SettingsKey.showStatusBar) private var showStatusBar = SettingsDefault.showStatusBar

    var body: some View {
        Form {
            Section("Reading View") {
                Picker("Typeface", selection: $fontFamily) {
                    ForEach(MarkingsFontFamily.allCases) { family in
                        Text(family.title).tag(family)
                    }
                }
                LabeledContent("Text size") {
                    HStack {
                        Slider(value: $fontSize, in: 11...30, step: 1)
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Text(sample)
                    .font(.system(size: CGFloat(fontSize), design: fontFamily.fontDesign))
                    .lineSpacing(CGFloat(fontSize) * 0.42)
                    .padding(.vertical, 4)
            }

            Section("Window") {
                Toggle("Follow the caret while writing", isOn: $syncScrolling)
                Text("In Split view the reading side keeps pace with where you are typing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("Show word count", isOn: $showStatusBar)
            }
        }
        .formStyle(.grouped)
    }

    private let sample = "The quick brown fox jumps over the lazy dog, and the reading view shows exactly how that will look."
}
