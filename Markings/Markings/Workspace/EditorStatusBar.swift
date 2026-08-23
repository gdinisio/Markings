//
//  EditorStatusBar.swift
//  Markings
//

import Foundation
import SwiftUI

/// A quiet line along the bottom: how much you have written on the left, where
/// you are on the right.
struct EditorStatusBar: View {

    let statistics: DocumentStatistics
    let caretLine: Int
    let caretColumn: Int
    let showsCaretPosition: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(statistics.words == 1 ? "1 word" : "\(statistics.words.formatted()) words")
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(statistics.readingMinutes) min read")

            if statistics.hasTasks {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(statistics.tasksCompleted)/\(statistics.tasksTotal) done")
            }

            Spacer(minLength: 12)

            if showsCaretPosition {
                Text("Ln \(caretLine + 1), Col \(caretColumn)")
                    .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .combine)
    }
}
