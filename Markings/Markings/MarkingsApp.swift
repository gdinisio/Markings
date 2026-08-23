//
//  MarkingsApp.swift
//  Markings
//
//  Created by Giovanni Di Nisio on 23/08/2026.
//

import Foundation
import SwiftUI

@main
struct MarkingsApp: App {

    var body: some Scene {
        DocumentGroup(newDocument: MarkingsDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 1180, height: 800)
        .commands {
            // The system’s own Show/Hide Sidebar item, wired to the split view,
            // rather than a lookalike of it.
            SidebarCommands()
            MarkingsCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
