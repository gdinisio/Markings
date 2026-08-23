//
//  ContentView.swift
//  Markings
//
//  Created by Giovanni Di Nisio on 23/08/2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: MarkingsDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(MarkingsDocument()))
}
