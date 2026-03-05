import Foundation

// MARK: - Shell Execution Result

struct ShellResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
    var succeeded: Bool { exitCode == 0 }
}

// MARK: - ShellRunner

actor ShellRunner {
    static let shared = ShellRunner()

    func run(_ command: String, workingDirectory: String? = nil) async throws -> ShellResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                if let wd = workingDirectory, !wd.isEmpty {
                    process.currentDirectoryURL = URL(fileURLWithPath: wd)
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    let output = String(data: stdoutData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""

                    continuation.resume(returning: ShellResult(
                        output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                        errorOutput: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
