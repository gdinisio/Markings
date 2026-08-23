//
//  DocumentInspector.swift
//  Markings
//

import AppKit
import SwiftUI

/// A read-out of what is in the document: length, structure and progress.
struct DocumentInspector: View {

    let statistics: DocumentStatistics
    let fileURL: URL?

    var body: some View {
        Form {
            Section("Length") {
                row("Words", value: statistics.words.formatted())
                row("Characters", value: statistics.characters.formatted())
                row("Characters without spaces", value: statistics.charactersExcludingSpaces.formatted())
                row("Lines", value: statistics.lines.formatted())
                row("Reading time", value: "\(statistics.readingMinutes) min")
            }

            Section("Structure") {
                row("Headings", value: statistics.headings.formatted())
                row("Paragraphs", value: statistics.paragraphs.formatted())
                row("Links", value: statistics.links.formatted())
                row("Images", value: statistics.images.formatted())
                row("Code blocks", value: statistics.codeBlocks.formatted())
                row("Tables", value: statistics.tables.formatted())
            }

            if statistics.hasTasks {
                Section("Tasks") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Completed")
                            Spacer()
                            Text("\(statistics.tasksCompleted) of \(statistics.tasksTotal)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        ProgressView(value: statistics.taskCompletion)
                            .progressViewStyle(.linear)
                    }
                    .padding(.vertical, 2)
                }
            }

            if let fileURL {
                Section("File") {
                    row("Name", value: fileURL.lastPathComponent)
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Document")
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
