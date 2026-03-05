import Foundation
import AppKit
import Observation
import KeyboardShortcuts

// MARK: - AppProvider

@Observable
final class AppProvider {
    static let shared = AppProvider()

    var apps: [AppItem] = []
    var isScanning: Bool = false

    // Explicitly tracked list — SwiftUI observes this directly
    var hotkeyedApps: [AppItem] = []

    // Manually added apps (browsed by user, persisted separately)
    private var manualAppPaths: [String] = []

    private var metadataQuery: NSMetadataQuery?
    private var appHotkeyEntries: [AppHotkeyEntry] = []

    private static let manualAppsKey = "manualAppPaths"

    private init() {
        loadHotkeyEntries()
        loadManualApps()
        startScan()
        observeWorkspaceNotifications()
    }

    // MARK: - Scanning

    func startScan() {
        isScanning = true

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "kMDItemContentTypeTree == 'com.apple.application-bundle'"
        )
        // Only scan /Applications and ~/Applications
        query.searchScopes = [
            "/Applications",
            NSString(string: "~/Applications").expandingTildeInPath
        ]
        query.sortDescriptors = [NSSortDescriptor(key: "kMDItemDisplayName", ascending: true)]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinish(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        metadataQuery = query
        query.start()
    }

    @objc private func queryDidFinish(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        query.stop()

        var discovered: [AppItem] = []
        query.disableUpdates()

        for i in 0 ..< query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem else { continue }
            guard let path = item.value(forAttribute: kMDItemPath as String) as? String else { continue }

            let url = URL(fileURLWithPath: path)
            let name = item.value(forAttribute: kMDItemDisplayName as String) as? String
                ?? url.deletingPathExtension().lastPathComponent

            guard path.hasSuffix(".app") else { continue }
            // Skip nested apps inside other .app bundles
            guard !path.contains(".app/Contents/") else { continue }

            let bundle = Bundle(url: url)
            let bundleId = bundle?.bundleIdentifier
            let appId = bundleId ?? path

            // Attach persisted hotkey name
            let hotkeyEntry = appHotkeyEntries.first { $0.id == appId }
            let hotkeyName = hotkeyEntry.map { KeyboardShortcuts.Name($0.hotkeyNameString) }

            let appItem = AppItem(
                id: appId,
                name: name,
                url: url,
                bundleIdentifier: bundleId,
                hotkeyName: hotkeyName
            )
            discovered.append(appItem)
        }

        query.enableUpdates()

        // Add manually browsed apps
        for path in manualAppPaths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let bundle = Bundle(url: url)
            let bundleId = bundle?.bundleIdentifier
            let appId = bundleId ?? path
            // Skip if already discovered
            if discovered.contains(where: { $0.id == appId }) { continue }

            let name = url.deletingPathExtension().lastPathComponent
            let hotkeyEntry = appHotkeyEntries.first { $0.id == appId }
            let hotkeyName = hotkeyEntry.map { KeyboardShortcuts.Name($0.hotkeyNameString) }

            discovered.append(AppItem(
                id: appId,
                name: name,
                url: url,
                bundleIdentifier: bundleId,
                hotkeyName: hotkeyName
            ))
        }

        // Deduplicate
        var seen = Set<String>()
        let deduped = discovered.filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.apps = deduped.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.isScanning = false
            self.rebuildHotkeyedApps()

            // Register hotkeys NOW that apps are loaded
            HotkeyManager.shared.registerAppHotkeys()
        }
    }

    // MARK: - Manual App Management

    func addManualApp(at url: URL) {
        let path = url.path
        guard !manualAppPaths.contains(path) else { return }
        manualAppPaths.append(path)
        persistManualApps()

        // Add to apps list immediately
        let bundle = Bundle(url: url)
        let bundleId = bundle?.bundleIdentifier
        let appId = bundleId ?? path
        guard !apps.contains(where: { $0.id == appId }) else { return }

        let name = url.deletingPathExtension().lastPathComponent
        let appItem = AppItem(id: appId, name: name, url: url, bundleIdentifier: bundleId, hotkeyName: nil)
        apps.append(appItem)
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func persistManualApps() {
        UserDefaults.standard.set(manualAppPaths, forKey: Self.manualAppsKey)
    }

    private func loadManualApps() {
        manualAppPaths = UserDefaults.standard.stringArray(forKey: Self.manualAppsKey) ?? []
    }

    // MARK: - Workspace notifications

    private func observeWorkspaceNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appsChanged),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appsChanged),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
    }

    @objc private func appsChanged() {
        startScan()
    }

    // MARK: - Hotkeyed Apps (explicit tracking for SwiftUI)

    func rebuildHotkeyedApps() {
        hotkeyedApps = apps.filter { app in
            guard let name = app.hotkeyName else { return false }
            return KeyboardShortcuts.getShortcut(for: name) != nil
        }
    }

    // MARK: - Hotkey Entries Persistence

    func saveHotkeyEntry(_ entry: AppHotkeyEntry) {
        if let index = appHotkeyEntries.firstIndex(where: { $0.id == entry.id }) {
            appHotkeyEntries[index] = entry
        } else {
            appHotkeyEntries.append(entry)
        }
        persistHotkeyEntries()

        // Update in-memory app item
        if let index = apps.firstIndex(where: { $0.id == entry.id }) {
            apps[index].hotkeyName = KeyboardShortcuts.Name(entry.hotkeyNameString)
        }
        rebuildHotkeyedApps()
    }

    func removeHotkeyEntry(for appId: String) {
        appHotkeyEntries.removeAll { $0.id == appId }
        persistHotkeyEntries()
        if let index = apps.firstIndex(where: { $0.id == appId }) {
            apps[index].hotkeyName = nil
        }
        rebuildHotkeyedApps()
    }

    // MARK: - Duplicate Hotkey Check

    func getHotkeyOwner(_ shortcut: KeyboardShortcuts.Shortcut, excludingAppId: String? = nil, excludingCommandId: UUID? = nil) -> String? {
        for app in apps {
            if app.id == excludingAppId { continue }
            if let name = app.hotkeyName,
               let existing = KeyboardShortcuts.getShortcut(for: name),
               existing == shortcut {
                return app.name
            }
        }
        for command in CommandStore.shared.commands {
            if command.id == excludingCommandId { continue }
            let name = command.hotkeyName
            if let existing = KeyboardShortcuts.getShortcut(for: name),
               existing == shortcut {
                return command.name
            }
        }
        return nil
    }

    private func persistHotkeyEntries() {
        guard let data = try? JSONEncoder().encode(appHotkeyEntries) else { return }
        UserDefaults.standard.set(data, forKey: SettingsKeys.appHotkeys)
    }

    private func loadHotkeyEntries() {
        guard
            let data = UserDefaults.standard.data(forKey: SettingsKeys.appHotkeys),
            let decoded = try? JSONDecoder().decode([AppHotkeyEntry].self, from: data)
        else { return }
        appHotkeyEntries = decoded
    }
}
