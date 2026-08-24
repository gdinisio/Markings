//
//  WelcomeWindow.swift
//  Markings
//

import AppKit
import Combine
import Foundation
import SwiftUI

/// The window Markings opens with.
///
/// A launch window earns its place only if it is faster than the alternative.
/// This one answers the three things somebody actually wants at launch —
/// carry on with what I had, start something new, open something else — and
/// gets out of the way. It can be switched off from its own footer.
struct WelcomeWindow: View {

    @Environment(\.newDocument) private var newDocument
    @Environment(\.openDocument) private var openDocument
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.showWelcomeAtLaunch) private var showAtLaunch = SettingsDefault.showWelcomeAtLaunch

    @State private var recents: [URL] = []
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            hero
            choices
        }
        .frame(width: 800, height: 540)
        .onAppear {
            reloadRecents()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { appeared = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            reloadRecents()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            // The accent tint under a material: it picks up whatever colour the
            // user chose in System Settings, and the material guarantees the
            // text on top stays legible in either appearance.
            LinearGradient(colors: [Color.accentColor.opacity(0.7), Color.accentColor.opacity(0.12)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            Rectangle().fill(.ultraThinMaterial)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                appMark
                    .padding(.bottom, 26)
                Text("Markings")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Markdown, natively.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                Spacer(minLength: 0)
                Text(versionSummary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 34)
            .padding(.bottom, 22)
        }
        .frame(width: 320)
    }

    /// The real app icon, which is the app's identity and already drawn far
    /// better than anything assembled here. The drawn mark stands in only if
    /// there is no icon to show.
    @ViewBuilder
    private var appMark: some View {
        if let icon = NSApplication.shared.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 124, height: 124)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)
        } else {
            DocumentMark(appeared: appeared)
        }
    }

    private var versionSummary: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    // MARK: - Choices

    private var choices: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Start") {
                        WelcomeRow(symbol: "doc",
                                   title: "New Document",
                                   detail: "An empty page",
                                   shortcut: "⌘N") {
                            start(text: "")
                        }
                        WelcomeRow(symbol: "doc.on.clipboard",
                                   title: "New from Clipboard",
                                   detail: clipboardDetail,
                                   shortcut: nil) {
                            start(text: NSPasteboard.general.string(forType: .string) ?? "")
                        }
                        .disabled(NSPasteboard.general.string(forType: .string) == nil)
                        WelcomeRow(symbol: "folder",
                                   title: "Open…",
                                   detail: "Choose a file on disk",
                                   shortcut: "⌘O") {
                            dismiss()
                            NSDocumentController.shared.openDocument(nil)
                        }
                    }

                    section("Templates") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                            GridItem(.flexible(), spacing: 10)],
                                  spacing: 10) {
                            ForEach(DocumentTemplate.all) { template in
                                TemplateCard(template: template) {
                                    start(text: template.body)
                                }
                            }
                        }
                    }

                    section("Recent") {
                        if recents.isEmpty {
                            Text("Documents you open will be listed here.")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                        } else {
                            ForEach(recents, id: \.self) { url in
                                RecentRow(url: url) {
                                    open(url)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()
            footer
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var footer: some View {
        HStack {
            Toggle("Show this window when Markings opens", isOn: $showAtLaunch)
                .toggleStyle(.checkbox)
                .font(.callout)
            Spacer(minLength: 12)
            if !recents.isEmpty {
                Button("Clear Recents") {
                    NSDocumentController.shared.clearRecentDocuments(nil)
                    reloadRecents()
                }
                .buttonStyle(.link)
                .font(.callout)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 10)
            content()
        }
    }

    private var clipboardDetail: String {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            return "Nothing on the clipboard"
        }
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return words == 1 ? "1 word ready to paste" : "\(words) words ready to paste"
    }

    // MARK: - Actions

    private func start(text: String) {
        dismiss()
        newDocument(MarkingsDocument(text: text))
    }

    private func open(_ url: URL) {
        dismiss()
        Task {
            do {
                try await openDocument(at: url)
            } catch {
                // The file has moved or been deleted; the recents list is stale.
                NSSound.beep()
                reloadRecents()
            }
        }
    }

    private func reloadRecents() {
        recents = Array(NSDocumentController.shared.recentDocumentURLs.prefix(8))
    }
}

// MARK: - The mark

/// A page of formatted text, drawn rather than shipped as an asset.
///
/// The bars draw themselves in on appear — enough motion to feel alive, not
/// enough to sit through twice.
private struct DocumentMark: View {

    var appeared: Bool

    private static var bars: [(width: CGFloat, height: CGFloat, opacity: Double)] {
        [(44, 9, 1.0), (58, 6, 0.8), (50, 6, 0.8), (34, 6, 0.55)]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing))
            .frame(width: 108, height: 108)
            .overlay {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Self.bars.indices, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(Self.bars[index].opacity))
                            .frame(width: appeared ? Self.bars[index].width : 0,
                                   height: Self.bars[index].height)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8)
                                .delay(0.15 + Double(index) * 0.07), value: appeared)
                    }
                }
                .frame(width: 58, alignment: .leading)
            }
            .shadow(color: Color.accentColor.opacity(0.4), radius: 20, y: 10)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .accessibilityHidden(true)
    }
}

// MARK: - Rows

private struct WelcomeRow: View {

    let symbol: String
    let title: String
    let detail: String
    let shortcut: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let shortcut {
                    Text(shortcut)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(hovering ? Color.primary.opacity(0.06) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct TemplateCard: View {

    let template: DocumentTemplate
    let action: () -> Void

    @State private var hovering = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: template.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name).font(.system(size: 12, weight: .semibold))
                    Text(template.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(shape.fill(Color.primary.opacity(hovering ? 0.07 : 0.035)))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.07)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Start a document from the \(template.name) template")
    }
}

private struct RecentRow: View {

    let url: URL
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer(minLength: 8)
                if let modified {
                    Text(modified.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(hovering ? Color.primary.opacity(0.06) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    /// The containing folder, with the home directory shortened the way Finder
    /// and the Open panel show it.
    private var location: String {
        let folder = url.deletingLastPathComponent().path(percentEncoded: false)
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        guard folder.hasPrefix(home) else { return folder }
        return "~/" + folder.dropFirst(home.count)
    }

    private var modified: Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
