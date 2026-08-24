//
//  DocumentTemplate.swift
//  Markings
//

import Foundation

/// A starting point offered on the welcome window.
///
/// Templates are ordinary Markdown — nothing here is a special document type.
/// Each one is chosen to be immediately useful rather than to demonstrate
/// syntax: a blank page is faster than a page you have to delete first.
nonisolated struct DocumentTemplate: Identifiable {

    var name: String
    var detail: String
    var symbol: String
    var body: String

    var id: String { name }

    static var all: [DocumentTemplate] {
        [notes, readme, checklist, article]
    }

    static var notes: DocumentTemplate {
        DocumentTemplate(
            name: "Meeting Notes",
            detail: "Attendees, notes, actions",
            symbol: "person.2",
            body: """
                # Meeting Notes

                **Date:** \(formattedToday)
                **Present:**

                ## Discussion

                -\u{0020}

                ## Decisions

                -\u{0020}

                ## Actions

                - [ ]\u{0020}
                """
        )
    }

    static var readme: DocumentTemplate {
        DocumentTemplate(
            name: "Read Me",
            detail: "Describe a project",
            symbol: "shippingbox",
            body: """
                # Project Name

                One sentence on what this is and who it is for.

                ## Requirements

                -\u{0020}

                ## Getting started

                ```sh
                git clone …
                ```

                ## Usage

                ## Licence
                """
        )
    }

    static var checklist: DocumentTemplate {
        DocumentTemplate(
            name: "Checklist",
            detail: "Things to get done",
            symbol: "checklist",
            body: """
                # Checklist

                ## Today

                - [ ]\u{0020}
                - [ ]\u{0020}
                - [ ]\u{0020}

                ## Later

                - [ ]\u{0020}
                """
        )
    }

    static var article: DocumentTemplate {
        DocumentTemplate(
            name: "Article",
            detail: "Long-form writing",
            symbol: "text.alignleft",
            body: """
                # Title

                *A standfirst: one or two lines setting up what follows.*

                ---

                Opening paragraph.

                ## First section

                ## Second section

                > A quote worth pulling out.

                ## Closing
                """
        )
    }

    private static var formattedToday: String {
        Date.now.formatted(date: .long, time: .omitted)
    }
}
