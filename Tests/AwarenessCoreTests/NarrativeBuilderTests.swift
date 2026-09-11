import XCTest
@testable import AwarenessCore

final class NarrativeBuilderTests: XCTestCase {
    func testNarrativeDoesNotMentionContextSwitches() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = ActivitySnapshot(
            appName: "Chrome",
            browserName: "Chrome",
            websiteTitle: "GitHub",
            websiteHost: "github.com",
            activityStartedAt: startedAt,
            contextSwitchCount: 42,
            capturedAt: startedAt
        )

        let content = NarrativeBuilder().build(
            from: snapshot,
            at: startedAt.addingTimeInterval(35)
        )
        let message = content.prefix + content.firstAccent + content.middle + content.secondAccent + content.suffix

        XCTAssertEqual(message, "You’ve been on github.com — GitHub — in Chrome for 35s.")
        XCTAssertFalse(message.localizedCaseInsensitiveContains("context"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("switch"))
    }
}
