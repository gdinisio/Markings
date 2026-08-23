//
//  MarkingsApp.swift
//  Markings
//
//  Created by Giovanni Di Nisio on 23/08/2026.
//

import SwiftUI

@main
struct MarkingsApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkingsDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
