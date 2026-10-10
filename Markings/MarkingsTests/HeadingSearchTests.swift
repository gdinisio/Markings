//
//  HeadingSearchTests.swift
//  MarkingsTests
//

import Foundation
import Testing

@Suite("Heading search")
struct HeadingSearchTests {

    private let items = [
        OutlineItem(level: 1, title: "Setup", line: 0),
        OutlineItem(level: 2, title: "Reset", line: 1),
        OutlineItem(level: 2, title: "Getting started", line: 2),
        OutlineItem(level: 1, title: "Supporting evidence", line: 3)
    ]

    @Test("An empty query matches everything, untouched")
    func emptyQuery() {
        #expect(HeadingSearch.filter("", in: items).map(\.title) == items.map(\.title))
        #expect(HeadingSearch.ranked("   ", in: items).map(\.title) == items.map(\.title))
    }

    @Test("The best match comes first in the jump list")
    func ranking() {
        #expect(HeadingSearch.ranked("set", in: items).map(\.title) == ["Setup", "Reset"],
                "a match at the start beats one in the middle")
    }

    @Test("Scattered letters match, but rank below a real run")
    func subsequence() {
        #expect(HeadingSearch.ranked("gs", in: items).map(\.title) == ["Getting started"])
        #expect(HeadingSearch.ranked("sup", in: items).first?.title == "Supporting evidence")
    }

    @Test("Filtering for the sidebar keeps document order")
    func filterKeepsOrder() {
        #expect(HeadingSearch.filter("ting", in: items).map(\.title)
                == ["Getting started", "Supporting evidence"],
                "an outline sorted by relevance is no longer an outline")
    }

    @Test("Case and accents are ignored")
    func insensitivity() {
        #expect(HeadingSearch.filter("SETUP", in: items).map(\.title) == ["Setup"])
        let accented = [OutlineItem(level: 1, title: "Café notes", line: 0)]
        #expect(HeadingSearch.filter("cafe", in: accented).count == 1)
    }

    @Test("A query that matches nothing returns nothing")
    func noMatches() {
        #expect(HeadingSearch.filter("zzzz", in: items).isEmpty)
        #expect(HeadingSearch.ranked("zzzz", in: items).isEmpty)
    }

    @Test("Equal matches stay in document order")
    func stableTies() {
        let twins = [
            OutlineItem(level: 1, title: "Alpha", line: 0),
            OutlineItem(level: 1, title: "Alps", line: 1)
        ]
        #expect(HeadingSearch.ranked("al", in: twins).map(\.line) == [0, 1])
    }

    @Test("Searching an empty outline is not an error")
    func emptyOutline() {
        #expect(HeadingSearch.filter("anything", in: []).isEmpty)
        #expect(HeadingSearch.ranked("", in: []).isEmpty)
    }
}
