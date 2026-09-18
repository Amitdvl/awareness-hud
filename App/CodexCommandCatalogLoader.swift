import Foundation
import AwarenessCore

enum CodexCommandCatalogLoader {
    static func load() throws -> [CodexSlashCommand] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let launcher = home.appendingPathComponent(".local/bin/agent-os")
        guard FileManager.default.isExecutableFile(atPath: launcher.path) else {
            throw CatalogError.unavailable
        }

        let process = Process()
        process.executableURL = launcher
        process.arguments = ["status", "--catalog", "--json"]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            home.appendingPathComponent(".local/bin").path,
            environment["PATH"] ?? "/usr/bin:/bin"
        ].joined(separator: ":")
        process.environment = environment

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CatalogError.failed(process.terminationStatus)
        }

        let skillsRoot = home.appendingPathComponent(".codex/skills", isDirectory: true)
        return try CodexCommandCatalog.parse(data) { name in
            let skillFile = skillsRoot.appendingPathComponent(name).appendingPathComponent("SKILL.md")
            return FileManager.default.fileExists(atPath: skillFile.path)
        }
    }
}

private enum CatalogError: LocalizedError {
    case unavailable
    case failed(Int32)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "The Codex command catalog is unavailable on this Mac."
        case .failed(let status):
            return "Could not load Codex commands (exit \(status))."
        }
    }
}
