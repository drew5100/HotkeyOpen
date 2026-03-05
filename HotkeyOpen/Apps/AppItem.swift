import Foundation
import AppKit
import KeyboardShortcuts

// MARK: - AppItem Model

struct AppItem: Identifiable, Equatable {
    let id: String  // bundle identifier or path
    let name: String
    let url: URL
    let bundleIdentifier: String?
    var hotkeyName: KeyboardShortcuts.Name?

    // Icon is loaded lazily and not stored persistently
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AppHotkeyEntry (persisted mapping of app id → hotkey name string)

struct AppHotkeyEntry: Codable, Identifiable {
    var id: String  // app bundle id or path
    var hotkeyNameString: String

    var hotkeyName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name(hotkeyNameString)
    }
}
