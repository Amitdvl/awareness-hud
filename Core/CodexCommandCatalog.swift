import Foundation

public struct CodexSlashCommand: Equatable, Sendable {
    public let name: String
    public let description: String

    public var invocation: String { "/\(name)" }
}

public enum CodexCommandCatalog {
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
