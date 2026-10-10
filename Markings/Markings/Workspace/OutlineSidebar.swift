//
//  OutlineSidebar.swift
//  Markings
//

import Foundation
import SwiftUI

/// The document's headings, in order, as a way to see its shape and move
/// around it — the same job a table of contents does in Pages.
struct OutlineSidebar: View {

    let items: [OutlineItem]
    let currentLine: Int
    var onSelect: (OutlineItem) -> Void

    @State private var filter = ""

    private var current: OutlineItem? {
        DocumentOutline.item(containing: currentLine, in: items)
    }

    /// Filtering keeps document order: an outline sorted by relevance is no
    /// longer an outline.
    private var visible: [OutlineItem] {
        HeadingSearch.filter(filter, in: items)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                empty
            } else if visible.isEmpty {
                noMatches
            } else {
                list
            }
        }
        .searchable(text: $filter, placement: .sidebar, prompt: "Filter headings")
        .navigationTitle("Outline")
        .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
    }

    private var list: some View {
        List(visible) { item in
            Button {
                onSelect(item)
            } label: {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(font(for: item.level))
                        .foregroundStyle(item.level <= 2 ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.leading, CGFloat(item.level - 1) * 11)
                .padding(.vertical, 4)
                .padding(.horizontal, 7)
                .background(item.id == current?.id ? Color.accentColor.opacity(0.16) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
            .help("Jump to \u{201C}\(item.title)\u{201D}")
        }
        .listStyle(.sidebar)
    }

    private var noMatches: some View {
        VStack(spacing: 6) {
            Text("No Matches")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("No heading contains \u{201C}\(filter)\u{201D}.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text("No Headings")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Headings you add appear here as an outline you can jump through.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func font(for level: Int) -> Font {
        switch level {
        case 1: return .system(size: 13, weight: .semibold)
        case 2: return .system(size: 12.5, weight: .medium)
        default: return .system(size: 12)
        }
    }
}
