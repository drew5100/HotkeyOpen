import Foundation
import AppKit
import KeyboardShortcuts

// MARK: - HotkeyManager

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var appProvider: AppProvider { AppProvider.shared }
    private var commandStore: CommandStore { CommandStore.shared }

    // Track registered hotkey names so we can clean them up
    private var registeredAppHotkeyNames: [KeyboardShortcuts.Name] = []
    private var registeredCommandHotkeyNames: [KeyboardShortcuts.Name] = []

    private init() {}

    // MARK: - App Hotkeys

    func registerAppHotkeys() {
        // Remove old handlers by replacing with no-ops
        for name in registeredAppHotkeyNames {
            KeyboardShortcuts.onKeyDown(for: name) {}
        }
        registeredAppHotkeyNames = []

        // Register from current apps list
        for app in appProvider.apps {
            guard let hotkeyName = app.hotkeyName else { continue }
            guard KeyboardShortcuts.getShortcut(for: hotkeyName) != nil else { continue }

            registeredAppHotkeyNames.append(hotkeyName)
            let url = app.url
            let name = app.name
            KeyboardShortcuts.onKeyDown(for: hotkeyName) {
                print("HotkeyManager: launching app '\(name)'")
                NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { _, error in
                    if let error = error {
                        print("Failed to launch \(name): \(error)")
                    }
                }
            }
        }

        print("HotkeyManager: registered \(registeredAppHotkeyNames.count) app hotkey(s)")
    }

    // MARK: - Command Hotkeys

    func registerCommandHotkeys() {
        // Remove old handlers
        for name in registeredCommandHotkeyNames {
            KeyboardShortcuts.onKeyDown(for: name) {}
        }
        registeredCommandHotkeyNames = []

        // Register from current commands list
        for command in commandStore.commands {
            let hotkeyName = command.hotkeyName
            guard let shortcut = KeyboardShortcuts.getShortcut(for: hotkeyName) else {
                continue
            }

            registeredCommandHotkeyNames.append(hotkeyName)
            let cmd = command.shellCommand
            let dir = command.workingDirectory
            let cmdName = command.name
            let inTerminal = command.runInTerminal
            print("HotkeyManager: registering command '\(cmdName)' with shortcut \(shortcut) (terminal: \(inTerminal))")

            KeyboardShortcuts.onKeyDown(for: hotkeyName) {
                print("HotkeyManager: running command '\(cmdName)' (terminal: \(inTerminal))")
                if inTerminal {
                    Self.runInTerminal(cmd, workingDirectory: dir)
                } else {
                    Self.runInBackground(cmd, name: cmdName, workingDirectory: dir)
                }
            }
        }

        print("HotkeyManager: registered \(registeredCommandHotkeyNames.count) command hotkey(s)")
    }

    // MARK: - Execution

    private static func runInBackground(_ command: String, name: String, workingDirectory: String?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = pipe
            process.standardError = pipe
            if let wd = workingDirectory, !wd.isEmpty {
                process.currentDirectoryURL = URL(fileURLWithPath: wd)
            }
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                print("Command '\(name)' exited \(process.terminationStatus): \(output.prefix(200))")
            } catch {
                print("Command '\(name)' failed: \(error)")
            }
        }
    }

    private static func runInTerminal(_ command: String, workingDirectory: String?) {
        // Build the full command with cd if working directory specified
        var fullCommand = ""
        if let wd = workingDirectory, !wd.isEmpty {
            let escaped = wd.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "\"", with: "\\\"")
            fullCommand = "cd \"\(escaped)\" && \(command)"
        } else {
            fullCommand = command
        }

        // Escape for AppleScript string
        let scriptSafe = fullCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
            activate
            do script "\(scriptSafe)"
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Failed to open Terminal: \(error)")
            }
        }
    }
}
