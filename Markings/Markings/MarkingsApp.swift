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
            // Show/Hide Toolbar and Customize Toolbar…, which is what puts the
            // toolbar customisation sheet in the View menu as well as on the
            // toolbar’s own contextual menu.
            ToolbarCommands()
            MarkingsCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
