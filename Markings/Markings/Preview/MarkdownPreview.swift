//
//  MarkdownPreview.swift
//  Markings
//

import AppKit
import Foundation
import SwiftUI

/// The reading view: the document as it is meant to be read.
struct MarkdownPreview: View {

    let blocks: [MarkdownBlock]
    let typography: PreviewTypography
    let measure: MarkingsMeasure
    /// Identity of the block to scroll into view, set when the caret moves or
    /// an outline heading is chosen.
    var scrollTarget: Int?
    var onToggleTask: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if blocks.isEmpty {
                    emptyState
                } else {
                    MarkdownBlockList(blocks: blocks,
                                      typography: typography,
                                      depth: 0,
                                      onToggleTask: onToggleTask)
                        .frame(maxWidth: measure.points > 0 ? CGFloat(measure.points) : .infinity,
                               alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 32)
                        .padding(.top, 28)
                        .padding(.bottom, 96)
                        .textSelection(.enabled)
                }
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView("Nothing to Preview",
                               systemImage: "doc.text",
                               description: Text("Start writing and the formatted document appears here."))
            .padding(.top, 80)
    }
}

/// A vertical run of blocks. Splitting this out of `MarkdownBlockView` is what
/// lets blocks nest inside quotes and list items without the two view types
/// chasing each other's opaque return types.
struct MarkdownBlockList: View {

    let blocks: [MarkdownBlock]
    let typography: PreviewTypography
    var depth: Int
    var onToggleTask: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                MarkdownBlockView(block: block,
                                  typography: typography,
                                  depth: depth,
                                  onToggleTask: onToggleTask)
                    .id(block.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MarkdownBlockView: View {

    let block: MarkdownBlock
    let typography: PreviewTypography
    var depth: Int
    var onToggleTask: (Int) -> Void

    var body: some View {
        switch block.kind {
        case .heading(let level, let text):
            heading(level: level, text: text)

        case .paragraph(let text):
            paragraph(text)

        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code, typography: typography)
                .padding(.bottom, typography.blockSpacing)

        case .thematicBreak:
            Divider()
                .padding(.vertical, typography.blockSpacing)

        case .blockQuote(let inner):
            quote(inner)

        case .list(let list):
            MarkdownListView(list: list,
                             typography: typography,
                             depth: depth,
                             onToggleTask: onToggleTask)
                .padding(.bottom, depth == 0 ? typography.blockSpacing : 0)

        case .table(let table):
            MarkdownTableView(table: table, typography: typography)
                .padding(.bottom, typography.blockSpacing)
        }
    }

    // MARK: - Blocks

    private func heading(level: Int, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            InlineMarkdown.text(text, font: typography.heading(level), codeFont: typography.code)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if level <= 2 {
                Divider().opacity(0.7)
            }
        }
        .padding(.top, typography.baseSize * (level == 1 ? 0.4 : 1.3))
        .padding(.bottom, typography.baseSize * 0.5)
    }

    @ViewBuilder
    private func paragraph(_ text: String) -> some View {
        if let image = MarkdownImageReference.standalone(in: text) {
            ImageReferenceView(reference: image, typography: typography)
                .padding(.bottom, typography.blockSpacing)
        } else {
            InlineMarkdown.text(text, font: typography.body, codeFont: typography.code)
                .lineSpacing(typography.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, typography.blockSpacing)
        }
    }

    private func quote(_ inner: [MarkdownBlock]) -> some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 3)
            nested(inner)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, typography.blockSpacing)
    }

    /// Type-erased so nesting never becomes a circular opaque type.
    private func nested(_ blocks: [MarkdownBlock]) -> AnyView {
        AnyView(
            MarkdownBlockList(blocks: blocks,
                              typography: typography,
                              depth: depth + 1,
                              onToggleTask: onToggleTask)
        )
    }
}

// MARK: - Lists

struct MarkdownListView: View {

    let list: MarkdownList
    let typography: PreviewTypography
    var depth: Int
    var onToggleTask: (Int) -> Void

    /// A list whose items hold more than one block reads better with air
    /// between the items — the same distinction CommonMark calls loose.
    private var isLoose: Bool {
        list.items.contains { $0.blocks.count > 1 }
    }

    private static let bullets = ["•", "◦", "▫︎"]

    var body: some View {
        VStack(alignment: .leading, spacing: isLoose ? typography.baseSize * 0.5 : typography.baseSize * 0.2) {
            ForEach(list.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    marker(for: item)
                    content(for: item)
                }
            }
        }
        .padding(.leading, depth > 0 ? typography.baseSize * 1.1 : 0)
    }

    @ViewBuilder
    private func marker(for item: MarkdownListItem) -> some View {
        if let checked = item.checked {
            Button {
                onToggleTask(item.markerLine)
            } label: {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: typography.baseSize * 0.95))
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(checked ? "Mark as not done" : "Mark as done")
            .accessibilityLabel(checked ? "Completed task" : "Incomplete task")
            .frame(width: typography.baseSize * 1.2, alignment: .leading)
        } else if list.isOrdered {
            Text("\(item.number).")
                .font(typography.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: typography.baseSize * 1.35, alignment: .trailing)
        } else {
            Text(Self.bullets[min(depth, Self.bullets.count - 1)])
                .font(typography.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: typography.baseSize * 1.2, alignment: .center)
        }
    }

    private func content(for item: MarkdownListItem) -> some View {
        AnyView(
            MarkdownBlockList(blocks: item.blocks,
                              typography: typography,
                              depth: depth + 1,
                              onToggleTask: onToggleTask)
        )
        .strikethrough(item.checked == true, color: .secondary)
        .foregroundStyle(item.checked == true ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Color.primary))
    }
}

// MARK: - Code

struct CodeBlockView: View {

    let language: String?
    let code: String
    let typography: PreviewTypography

    @State private var didCopy = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(typography.code)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(shape.fill(Color.primary.opacity(0.04)))
        .overlay(shape.strokeBorder(Color.primary.opacity(0.07)))
        .clipShape(shape)
    }

    @ViewBuilder
    private var header: some View {
        if let language, !language.isEmpty {
            HStack {
                Text(language.uppercased())
                    .font(typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                copyButton
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 7)
            Divider().opacity(0.6)
        }
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            didCopy = true
        } label: {
            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                .font(typography.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(didCopy ? Color.accentColor : Color.secondary)
        .help("Copy this code block")
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.6))
            didCopy = false
        }
    }
}

// MARK: - Tables

struct MarkdownTableView: View {

    let table: MarkdownTable
    let typography: PreviewTypography

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(table.header.enumerated()), id: \.offset) { pair in
                        cell(pair.element, isHeader: true)
                            .gridColumnAlignment(alignment(for: pair.offset))
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(Array(table.rows.enumerated()), id: \.offset) { row in
                    GridRow {
                        ForEach(Array(row.element.enumerated()), id: \.offset) { pair in
                            cell(pair.element, isHeader: false)
                        }
                    }
                    if row.offset < table.rows.count - 1 {
                        Divider().gridCellUnsizedAxes(.horizontal).opacity(0.5)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .background(shape.fill(Color.primary.opacity(0.02)))
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
        .clipShape(shape)
    }

    private func cell(_ text: String, isHeader: Bool) -> some View {
        InlineMarkdown.text(text,
                            font: isHeader ? typography.body.weight(.semibold) : typography.body,
                            codeFont: typography.code)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
    }

    private func alignment(for column: Int) -> HorizontalAlignment {
        let value = column < table.alignments.count ? table.alignments[column] : .leading
        switch value {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

// MARK: - Images

/// Shows what an image reference points at rather than a broken image well.
struct ImageReferenceView: View {

    let reference: MarkdownImageReference
    let typography: PreviewTypography

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "photo")
                .font(.system(size: typography.baseSize * 1.3))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(reference.alt.isEmpty ? reference.displayName : reference.alt)
                    .font(typography.body)
                    .foregroundStyle(.primary)
                Text(reference.target)
                    .font(typography.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Color.primary.opacity(0.04)))
        .overlay(shape.strokeBorder(Color.primary.opacity(0.07)))
        .accessibilityLabel("Image: \(reference.alt.isEmpty ? reference.displayName : reference.alt)")
    }
}
