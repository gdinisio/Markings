//
//  HeadingSearch.swift
//  Markings
//

import Foundation

/// Matching for the outline filter and for Go to Heading.
///
/// Two different jobs, so two entry points: filtering a sidebar must keep the
/// document's order, because an outline out of order is not an outline. Ranking
/// for a jump list must not, because the best match belongs at the top where
/// Return will hit it.
nonisolated enum HeadingSearch {

    /// Matches in document order, for the outline sidebar.
    static func filter(_ query: String, in items: [OutlineItem]) -> [OutlineItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { score(trimmed, against: $0.title) != nil }
    }

    /// Matches best first, for the jump list.
    static func ranked(_ query: String, in items: [OutlineItem]) -> [OutlineItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }

        return items
            .compactMap { item -> (item: OutlineItem, score: Int)? in
                guard let score = score(trimmed, against: item.title) else { return nil }
                return (item, score)
            }
            // Equal scores keep document order, which is a more useful
            // tie-break than anything else available.
            .enumerated()
            .sorted { ($0.element.score, $0.offset) < ($1.element.score, $1.offset) }
            .map(\.element.item)
    }

    /// Lower is better, or `nil` for no match.
    ///
    /// A run of the typed characters beats letters scattered through the title,
    /// and an earlier match beats a later one — so typing "set" puts "Setup"
    /// above "Reset" and both above "Supporting evidence tables".
    private static func score(_ query: String, against title: String) -> Int? {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        if let range = title.range(of: query, options: options) {
            return title.distance(from: title.startIndex, to: range.lowerBound)
        }
        return isSubsequence(query, of: title) ? 1_000 : nil
    }

    /// Whether the typed characters appear in order, so "gs" finds
    /// "Getting started".
    private static func isSubsequence(_ query: String, of title: String) -> Bool {
        let lowered = title.lowercased()
        var index = lowered.startIndex

        for character in query.lowercased() where !character.isWhitespace {
            guard index < lowered.endIndex,
                  let found = lowered[index...].firstIndex(of: character) else { return false }
            index = lowered.index(after: found)
        }
        return true
    }
}
