import Foundation

public struct CodexSlashCommand: Equatable, Sendable {
    public let name: String
    public let description: String

    public var invocation: String { "/\(name)" }
}

public enum CodexCommandCatalog {
    private static let selectedStandaloneCommands: [String: String] = [
        "book": "Research, write, fact-check, and deliver a validated nonfiction EPUB.",
        "current-limiting-factor": "Identify the one bottleneck most constraining progress toward a live objective.",
        "engineer-algorithm": "Question, delete, simplify, accelerate, then automate a workflow—in that order.",
        "fallacy-check": "Check consequential reasoning for a clear, material inference error.",
        "image-art-direction": "Direct detailed image generation or editing while preserving visual decisions across iterations.",
        "mentor": "Retrieve the most relevant personal operating principles, reminders, and next moves.",
        "openai-aesthetic-images": "Create editorial color-field artwork in a deliberate OpenAI-inspired visual language.",
        "outcome-loop": "Own an outcome through iterative action, verification, and documented results.",
        "pamphlet": "Research and create a concise finished knowledge pamphlet as PDF and Markdown.",
        "production-repo-baseline": "Set up Git, safe defaults, Dependabot, and real CI for a repository.",
        "viral-sense": "Find high-performing X bookmarks and explain their viral strategies."
    ]

    public static func parse(_ data: Data, isInstalled: (String) -> Bool) throws -> [CodexSlashCommand] {
        let catalog = try JSONDecoder().decode(CatalogDocument.self, from: data)
        let manifestCommands = Dictionary(uniqueKeysWithValues: catalog.commands.map { ($0.id, $0) })
        var seen = Set<String>()
        var result: [CodexSlashCommand] = []

        for entry in catalog.classifiedCatalogue where entry.group == "personal-slash-commands" {
            guard !entry.id.isEmpty, !seen.contains(entry.id) else { continue }

            if entry.source == "manifest/commands.json" {
                guard let command = manifestCommands[entry.id],
                      command.disposition != "intentionally-excluded",
                      isInstalled(entry.id) else { continue }
            }

            seen.insert(entry.id)
            result.append(CodexSlashCommand(name: entry.id, description: entry.description ?? ""))
        }

        for (name, description) in selectedStandaloneCommands where !seen.contains(name) && isInstalled(name) {
            seen.insert(name)
            result.append(CodexSlashCommand(name: name, description: description))
        }

        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private struct CatalogDocument: Decodable {
    let commands: [ManifestCommand]
    let classifiedCatalogue: [CatalogEntry]
}

private struct ManifestCommand: Decodable {
    let id: String
    let disposition: String
}

private struct CatalogEntry: Decodable {
    let group: String
    let id: String
    let description: String?
    let source: String
}
