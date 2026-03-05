import Foundation
import KeyboardShortcuts

// MARK: - CommandItem Model

struct CommandItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var shellCommand: String
    var workingDirectory: String?
    var hotkeyNameString: String
    var runInTerminal: Bool

    init(
        id: UUID = UUID(),
        name: String,
        shellCommand: String,
        workingDirectory: String? = nil,
        runInTerminal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.shellCommand = shellCommand
        self.workingDirectory = workingDirectory
        self.runInTerminal = runInTerminal
        self.hotkeyNameString = "command_\(id.uuidString)"
    }

    var hotkeyName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name(hotkeyNameString)
    }

    // Handle decoding from older versions that didn't have runInTerminal
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shellCommand = try container.decode(String.self, forKey: .shellCommand)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        hotkeyNameString = try container.decode(String.self, forKey: .hotkeyNameString)
        runInTerminal = try container.decodeIfPresent(Bool.self, forKey: .runInTerminal) ?? false
    }
}
