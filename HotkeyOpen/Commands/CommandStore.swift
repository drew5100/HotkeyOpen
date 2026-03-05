import Foundation
import Observation

// MARK: - CommandStore

@Observable
final class CommandStore {
    static let shared = CommandStore()

    var commands: [CommandItem] = [] {
        didSet { persist() }
    }

    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    // MARK: - CRUD

    func add(_ command: CommandItem) {
        commands.append(command)
    }

    func update(_ command: CommandItem) {
        guard let index = commands.firstIndex(where: { $0.id == command.id }) else { return }
        commands[index] = command
    }

    func delete(_ command: CommandItem) {
        commands.removeAll { $0.id == command.id }
    }

    func delete(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        commands.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        defaults.set(data, forKey: SettingsKeys.commands)
    }

    private func load() {
        guard
            let data = defaults.data(forKey: SettingsKeys.commands),
            let decoded = try? JSONDecoder().decode([CommandItem].self, from: data)
        else { return }
        commands = decoded
    }
}
