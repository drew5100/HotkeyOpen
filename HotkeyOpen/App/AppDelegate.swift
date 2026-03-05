import AppKit
import SwiftUI

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private static var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar agent — no Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Start app scanner (async — hotkeys registered when scan finishes via AppProvider.queryDidFinish)
        _ = AppProvider.shared

        // Register command hotkeys immediately (they don't depend on app scan)
        HotkeyManager.shared.registerCommandHotkeys()
    }

    // MARK: - Settings Window

    static func openSettings() {
        if let wc = settingsWindowController, let win = wc.window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HotkeyOpen Settings"
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false

        let wc = NSWindowController(window: window)
        settingsWindowController = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
