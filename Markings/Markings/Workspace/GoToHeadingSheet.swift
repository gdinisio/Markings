//
//  GoToHeadingSheet.swift
//  Markings
//

import Foundation
import SwiftUI

/// Jump anywhere in a document from the keyboard.
///
/// A long document outgrows scrolling, and the outline sidebar costs a column
/// of width to keep open. This is the same answer Xcode's Open Quickly gives:
/// type a few letters, press Return.
struct GoToHeadingSheet: View {

    let items: [OutlineItem]
    var onSelect: (OutlineItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var fieldIsFocused: Bool

    private var matches: [OutlineItem] {
        HeadingSearch.ranked(query, in: items)
    }

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider()
            results
            Divider()
            hints
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - Field

    private var field: some View {
        HStack(spacing: 9) {
            Image(systemName: "text.magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Go to heading", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldIsFocused)
                .onSubmit { jumpToHighlighted() }
                .onKeyPress(.upArrow) { move(by: -1); return .handled }
                .onKeyPress(.downArrow) { move(by: 1); return .handled }
                .onKeyPress(.escape) { dismiss(); return .handled }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .onAppear { fieldIsFocused = true }
        .onChange(of: query) { _, _ in highlighted = 0 }
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        if items.isEmpty {
            message("This document has no headings yet.")
        } else if matches.isEmpty {
            message("No heading matches \u{201C}\(query)\u{201D}.")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(matches.indices, id: \.self) { index in
                            row(matches[index], isHighlighted: index == highlighted)
                                .id(index)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: highlighted) { _, index in
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }

    private func row(_ item: OutlineItem, isHighlighted: Bool) -> some View {
        Button {
            select(item)
        } label: {
            HStack(spacing: 11) {
                Text(String(repeating: "#", count: item.level))
                    .font(.system(size: 11, design: .monospaced))
                    .opacity(0.55)
                    .frame(width: 40, alignment: .trailing)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(ancestry(of: item))
                        .font(.caption)
                        .opacity(0.65)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer(minLength: 8)
                Text("Line \(item.line + 1)")
                    .font(.caption)
                    .opacity(0.55)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isHighlighted ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
            .background(isHighlighted ? Color.accentColor : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Where this heading sits, so two sections with the same name are telling
    /// apart by something other than their line number.
    private func ancestry(of item: OutlineItem) -> String {
        let ancestors = DocumentOutline.path(to: item.line, in: items).dropLast()
        guard !ancestors.isEmpty else { return "Top level" }
        return ancestors.map(\.title).joined(separator: " \u{203A} ")
    }

    private func message(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var hints: some View {
        HStack(spacing: 14) {
            hint("return", "Go")
            hint("arrow.up.arrow.down", "Choose")
            hint("escape", "Close")
            Spacer(minLength: 0)
            if !matches.isEmpty {
                Text(matches.count == 1 ? "1 heading" : "\(matches.count) headings")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func hint(_ symbol: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(label)
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }

    // MARK: - Actions

    private func move(by delta: Int) {
        guard !matches.isEmpty else { return }
        highlighted = min(max(highlighted + delta, 0), matches.count - 1)
    }

    private func jumpToHighlighted() {
        guard matches.indices.contains(highlighted) else { return }
        select(matches[highlighted])
    }

    private func select(_ item: OutlineItem) {
        dismiss()
        onSelect(item)
    }
}
