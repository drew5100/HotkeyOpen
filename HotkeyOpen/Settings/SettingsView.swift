import SwiftUI
import KeyboardShortcuts
import ServiceManagement

// MARK: - SettingsView

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(0)

            AppsSettingsTab()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
                .tag(1)

            CommandsSettingsTab()
                .tabItem { Label("Commands", systemImage: "terminal") }
                .tag(2)
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @AppStorage(SettingsKeys.launchAtLogin) private var launchAtLogin = false
    @State private var appProvider = AppProvider.shared
    @State private var commandStore = CommandStore.shared
    // Bumped to force re-evaluation when any shortcut changes
    @State private var refreshID = UUID()

    private var hotkeyedCommands: [CommandItem] {
        commandStore.commands.filter { cmd in
            KeyboardShortcuts.getShortcut(for: cmd.hotkeyName) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Startup") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Launch at login error: \(error)")
                            }
                        }
                }

                Section("Active App Hotkeys") {
                    if appProvider.hotkeyedApps.isEmpty {
                        Text("No app hotkeys assigned. Go to the Apps tab to set them up.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(appProvider.hotkeyedApps) { app in
                            HotkeyedAppRow(app: app)
                        }
                    }
                }

                Section("Active Command Hotkeys") {
                    if hotkeyedCommands.isEmpty {
                        Text("No command hotkeys assigned. Go to the Commands tab to set them up.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(hotkeyedCommands) { cmd in
                            HotkeyedCommandRow(command: cmd)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            .id(refreshID)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"))) { _ in
            refreshID = UUID()
        }
        .onAppear {
            refreshID = UUID()
        }
    }
}

// MARK: - HotkeyedAppRow (General tab)

private struct HotkeyedAppRow: View {
    let app: AppItem

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 24, height: 24)

            Text(app.name)
                .lineLimit(1)

            Spacer()

            if let hotkeyName = app.hotkeyName {
                KeyboardShortcuts.Recorder("", name: hotkeyName, onChange: { shortcut in
                    handleChange(shortcut: shortcut)
                })
            }
        }
    }

    private func handleChange(shortcut: KeyboardShortcuts.Shortcut?) {
        if let shortcut = shortcut,
           let owner = AppProvider.shared.getHotkeyOwner(shortcut, excludingAppId: app.id) {
            if let name = app.hotkeyName {
                KeyboardShortcuts.reset(name)
            }
            print("Hotkey already used by '\(owner)'")
            return
        }

        let entry = AppHotkeyEntry(id: app.id, hotkeyNameString: "app_\(app.id)")
        if shortcut != nil {
            AppProvider.shared.saveHotkeyEntry(entry)
        } else {
            AppProvider.shared.removeHotkeyEntry(for: app.id)
        }
        HotkeyManager.shared.registerAppHotkeys()
    }
}

// MARK: - HotkeyedCommandRow (General tab)

private struct HotkeyedCommandRow: View {
    let command: CommandItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)

            Text(command.name)
                .lineLimit(1)

            Spacer()

            KeyboardShortcuts.Recorder("", name: command.hotkeyName, onChange: { shortcut in
                if shortcut == nil {
                    KeyboardShortcuts.reset(command.hotkeyName)
                }
                HotkeyManager.shared.registerCommandHotkeys()
            })
        }
    }
}

// MARK: - Apps Tab

private struct AppsSettingsTab: View {
    @State private var appProvider = AppProvider.shared
    @State private var searchText = ""

    private var filteredApps: [AppItem] {
        if searchText.isEmpty { return appProvider.apps }
        return appProvider.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter apps\u{2026}", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(
                Rectangle().frame(height: 1).foregroundStyle(Color(nsColor: .separatorColor)),
                alignment: .bottom
            )

            if appProvider.isScanning {
                Spacer()
                ProgressView("Scanning applications\u{2026}")
                Spacer()
            } else {
                List(filteredApps) { app in
                    AppHotkeyRow(app: app)
                }
                .listStyle(.plain)
            }

            // Footer
            HStack {
                Text("\(appProvider.apps.count) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Browse\u{2026}") { browseForApp() }
                    .buttonStyle(.borderless)
                    .font(.caption)
                Button("Refresh") { appProvider.startScan() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Select an application to add"

        if panel.runModal() == .OK, let url = panel.url {
            appProvider.addManualApp(at: url)
        }
    }
}

// MARK: - AppHotkeyRow (Apps tab)

private struct AppHotkeyRow: View {
    let app: AppItem
    private let hotkeyName: KeyboardShortcuts.Name

    init(app: AppItem) {
        self.app = app
        self.hotkeyName = KeyboardShortcuts.Name("app_\(app.id)")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)

            Text(app.name)
                .lineLimit(1)

            Spacer()

            KeyboardShortcuts.Recorder("", name: hotkeyName, onChange: { shortcut in
                handleChange(shortcut: shortcut)
            })
        }
        .padding(.vertical, 4)
    }

    private func handleChange(shortcut: KeyboardShortcuts.Shortcut?) {
        // Duplicate check
        if let shortcut = shortcut,
           let owner = AppProvider.shared.getHotkeyOwner(shortcut, excludingAppId: app.id) {
            KeyboardShortcuts.reset(hotkeyName)
            print("Hotkey already used by '\(owner)'")
            return
        }

        let entry = AppHotkeyEntry(id: app.id, hotkeyNameString: "app_\(app.id)")
        if shortcut != nil {
            AppProvider.shared.saveHotkeyEntry(entry)
        } else {
            AppProvider.shared.removeHotkeyEntry(for: app.id)
        }
        HotkeyManager.shared.registerAppHotkeys()
    }
}

// MARK: - Commands Tab

private struct CommandsSettingsTab: View {
    @State private var commandStore = CommandStore.shared
    @State private var showingAddSheet = false
    @State private var editingCommand: CommandItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            if commandStore.commands.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No Commands")
                        .font(.headline)
                    Text("Add shell commands and assign hotkeys to run them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Add Command") { showingAddSheet = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(commandStore.commands) { command in
                        SettingsCommandRow(command: command) {
                            editingCommand = command
                        }
                    }
                    .onDelete { offsets in
                        // Reset hotkeys for deleted commands
                        for i in offsets {
                            KeyboardShortcuts.reset(commandStore.commands[i].hotkeyName)
                        }
                        commandStore.delete(at: offsets)
                        HotkeyManager.shared.registerCommandHotkeys()
                    }
                }
                .listStyle(.plain)
            }

            HStack {
                Text("\(commandStore.commands.count) command\(commandStore.commands.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showingAddSheet = true } label: {
                    Label("Add", systemImage: "plus").font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showingAddSheet) {
            CommandEditSheet(command: nil) { newCommand in
                commandStore.add(newCommand)
                HotkeyManager.shared.registerCommandHotkeys()
            }
        }
        .sheet(item: $editingCommand) { command in
            CommandEditSheet(command: command) { updated in
                commandStore.update(updated)
                HotkeyManager.shared.registerCommandHotkeys()
            }
        }
    }
}

// MARK: - SettingsCommandRow

private struct SettingsCommandRow: View {
    let command: CommandItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(command.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if command.runInTerminal {
                        Text("Terminal")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(command.shellCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            KeyboardShortcuts.Recorder("", name: command.hotkeyName, onChange: { shortcut in
                if let shortcut = shortcut,
                   let owner = AppProvider.shared.getHotkeyOwner(shortcut, excludingCommandId: command.id) {
                    KeyboardShortcuts.reset(command.hotkeyName)
                    print("Hotkey already used by '\(owner)'")
                    return
                }
                HotkeyManager.shared.registerCommandHotkeys()
            })

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Edit\u{2026}", action: onEdit)
            Button("Delete", role: .destructive) {
                KeyboardShortcuts.reset(command.hotkeyName)
                CommandStore.shared.delete(command)
                HotkeyManager.shared.registerCommandHotkeys()
            }
        }
    }
}

// MARK: - CommandEditSheet

struct CommandEditSheet: View {
    let command: CommandItem?
    let onSave: (CommandItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var shellCommand: String
    @State private var workingDirectory: String
    @State private var runInTerminal: Bool
    @State private var testOutput: String = ""
    @State private var isTesting: Bool = false
    @State private var testError: Bool = false

    init(command: CommandItem?, onSave: @escaping (CommandItem) -> Void) {
        self.command = command
        self.onSave = onSave
        _name = State(initialValue: command?.name ?? "")
        _shellCommand = State(initialValue: command?.shellCommand ?? "")
        _workingDirectory = State(initialValue: command?.workingDirectory ?? "")
        _runInTerminal = State(initialValue: command?.runInTerminal ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(command == nil ? "New Command" : "Edit Command")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || shellCommand.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Shell Command") {
                    TextField("e.g. /usr/local/bin/git pull", text: $shellCommand, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3...6)
                }

                Section("Options") {
                    Toggle("Run in Terminal", isOn: $runInTerminal)
                    Text("Opens a new Terminal window to run the command. Use this for interactive commands like editors or REPLs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Working Directory (optional)") {
                    HStack {
                        TextField("/path/to/directory", text: $workingDirectory)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse\u{2026}") { browseDirectory() }
                    }
                }

                Section("Test") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: testCommand) {
                                if isTesting {
                                    ProgressView().scaleEffect(0.7).frame(width: 16, height: 16)
                                } else {
                                    Label("Test", systemImage: "play.fill")
                                }
                            }
                            .disabled(shellCommand.isEmpty || isTesting)
                            .buttonStyle(.bordered)

                            if !testOutput.isEmpty {
                                Image(systemName: testError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(testError ? .red : .green)
                            }
                        }

                        if !testOutput.isEmpty {
                            ScrollView {
                                Text(testOutput)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(testError ? .red : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                            .frame(height: 80)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor))
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 480)
    }

    private func save() {
        var updated = command ?? CommandItem(name: name, shellCommand: shellCommand, runInTerminal: runInTerminal)
        updated.name = name
        updated.shellCommand = shellCommand
        updated.workingDirectory = workingDirectory.isEmpty ? nil : workingDirectory
        updated.runInTerminal = runInTerminal
        onSave(updated)
        dismiss()
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }

    private func testCommand() {
        guard !shellCommand.isEmpty else { return }
        isTesting = true
        testOutput = ""
        testError = false

        Task {
            do {
                let result = try await ShellRunner.shared.run(
                    shellCommand,
                    workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory
                )
                await MainActor.run {
                    testOutput = result.output.isEmpty
                        ? (result.errorOutput.isEmpty ? "(no output)" : result.errorOutput)
                        : result.output
                    testError = !result.succeeded
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testOutput = error.localizedDescription
                    testError = true
                    isTesting = false
                }
            }
        }
    }
}
