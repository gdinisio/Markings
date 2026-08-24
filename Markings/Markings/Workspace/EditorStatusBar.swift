//
//  EditorStatusBar.swift
//  Markings
//

import Foundation
import SwiftUI

/// A quiet line along the bottom: where you are on the left, how much you have
/// written on the right.
///
/// The left half is the heading path rather than a line number, because "which
/// section am I in" is the question a writer is actually asking. Each crumb
/// jumps to its heading.
struct EditorStatusBar: View {

    let statistics: DocumentStatistics
    let path: [OutlineItem]
    let caretLine: Int
    let caretColumn: Int
    let showsCaretPosition: Bool
    var onSelect: (OutlineItem) -> Void

    var body: some View {
        HStack(spacing: 10) {
            breadcrumb
            Spacer(minLength: 16)
            counts
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var breadcrumb: some View {
        if path.isEmpty {
            Label("No headings yet", systemImage: "number")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 5) {
                ForEach(path) { item in
                    if item.id != path.first?.id {
                        Image(systemName: "chevron.compact.right")
                            .foregroundStyle(.quaternary)
                    }
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(item.id == path.last?.id ? AnyShapeStyle(Color.primary)
                                                                      : AnyShapeStyle(Color.secondary))
                    }
                    .buttonStyle(.plain)
                    .help("Jump to \u{201C}\(item.title)\u{201D}")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var counts: some View {
        HStack(spacing: 10) {
            Text(statistics.words == 1 ? "1 word" : "\(statistics.words.formatted()) words")
            separator
            Text("\(statistics.readingMinutes) min read")

            if statistics.hasTasks {
                separator
                Label("\(statistics.tasksCompleted)/\(statistics.tasksTotal)", systemImage: "checklist")
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
            }

            if showsCaretPosition {
                separator
                Text("Ln \(caretLine + 1), Col \(caretColumn)")
                    .monospacedDigit()
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private var separator: some View {
        Text(verbatim: "·").foregroundStyle(.quaternary)
    }
}
