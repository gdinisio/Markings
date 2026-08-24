//
//  MarkingsAppDelegate.swift
//  Markings
//

import AppKit
import Foundation

/// The two pieces of launch behaviour that only AppKit can express.
final class MarkingsAppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Registering the default here means `bool(forKey:)` below and
        // `@AppStorage` in the welcome window agree about what "unset" means.
        UserDefaults.standard.register(defaults: [
            SettingsKey.showWelcomeAtLaunch: SettingsDefault.showWelcomeAtLaunch
        ])
    }

    /// An untitled document stacked on top of the welcome window is noise, and
    /// returning `false` also stops the Open panel appearing over it. When the
    /// welcome window is switched off, the standard behaviour returns.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: SettingsKey.showWelcomeAtLaunch)
    }
}
