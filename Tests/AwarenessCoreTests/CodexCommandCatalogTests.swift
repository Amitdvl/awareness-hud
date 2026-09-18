import Foundation
import XCTest
@testable import AwarenessCore

final class CodexCommandCatalogTests: XCTestCase {
    private let catalog = """
    {
      "commands": [
        {"id":"archive","disposition":"portable-core"},
        {"id":"commands","disposition":"portable-core"},
        {"id":"margins","disposition":"intentionally-excluded"}
      ],
      "classifiedCatalogue": [
        {"group":"standalone-skills","id":"imagegen","source":"manifest/skills.json"},
        {"group":"personal-slash-commands","id":"margins","description":"Unavailable","source":"manifest/commands.json"},
        {"group":"personal-slash-commands","id":"commands","description":"List commands","source":"manifest/commands.json"},
        {"group":"personal-slash-commands","id":"archive","description":"Archive a project","source":"manifest/commands.json"},
        {"group":"personal-slash-commands","id":"personal-plugin","description":"Plugin command","source":"personal-plugin"}
      ]
    }
    """

    func testListsOnlyAvailablePersonalCommandsAndNotSkills() throws {
        let commands = try CodexCommandCatalog.parse(Data(catalog.utf8)) { _ in true }
        XCTAssertEqual(commands.map(\.invocation), ["/archive", "/commands", "/personal-plugin"])
    }

    func testOmitsManifestCommandsMissingFromThisCodexInstallation() throws {
        let commands = try CodexCommandCatalog.parse(Data(catalog.utf8)) { $0 == "archive" }
        XCTAssertEqual(commands.map(\.invocation), ["/archive", "/personal-plugin"])
    }
}
