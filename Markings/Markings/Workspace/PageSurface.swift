//
//  PageSurface.swift
//  Markings
//

import AppKit
import Foundation
import SwiftUI

/// Puts a document on a page, and the page on a surface.
///
/// A text column floating in a full-bleed white rectangle gives no sense of
/// where the writing area ends; the chosen line width just looks like wasted
/// room. Setting the column on its own lit page against a recessed ground makes
/// the measure deliberate — the same reading Pages and Preview give a document —
/// and gives the window somewhere for its edges to be.
///
/// Both colours are system colours, so this follows the appearance rather than
/// inventing one.
struct PageSurface<Content: View>: View {

    var measure: MarkingsMeasure
    /// Extra page beyond the text column itself, so the words are not pressed
    /// against the paper's edge.
    var margin: CGFloat = 44
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(alignment: .center) { page }
            .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var page: some View {
        let width = measure.points > 0 ? CGFloat(measure.points) + margin * 2 : CGFloat.infinity
        Rectangle()
            .fill(Color(nsColor: .textBackgroundColor))
            .frame(maxWidth: width)
            .shadow(color: .black.opacity(0.12), radius: 16)
    }
}
