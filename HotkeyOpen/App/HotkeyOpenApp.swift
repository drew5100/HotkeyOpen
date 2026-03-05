import SwiftUI

// MARK: - HotkeyOpenApp

@main
struct HotkeyOpenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("HotkeyOpen", systemImage: "command.square.fill") {
            Button("Settings\u{2026}") {
                AppDelegate.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit HotkeyOpen") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
