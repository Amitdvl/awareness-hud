import XCTest
@testable import AwarenessCore

final class FocusAnalyticsTests: XCTestCase {
    func testFocusBlockRecordsMeasuredContextSwitchesAndUserReviewSeparately() throws {
        let start = date("2026-09-12T09:00:00Z")
        let safari = FocusActivitySource(appName: "Safari")
        let slack = FocusActivitySource(appName: "Slack")
        var store = FocusDataStore()

        store.start(intention: "Write project brief", source: safari, at: start, timeZone: .gmt)
        store.record(source: slack, at: date("2026-09-12T09:10:00Z"))
        store.record(source: safari, at: date("2026-09-12T09:12:00Z"))
        let block = try XCTUnwrap(store.finish(at: date("2026-09-12T09:20:00Z")))

        XCTAssertEqual(block.observedDuration, 1_200)
        XCTAssertEqual(block.sourceDurations.first?.source, safari)
        XCTAssertEqual(block.sourceDurations.first?.duration, 1_080)
        XCTAssertEqual(block.sourceDurations.last?.source, slack)
        XCTAssertEqual(block.sourceDurations.last?.duration, 120)
        XCTAssertNil(block.review)

        let review = FocusBlockReview(
            outcome: .partiallyCompleted,
            note: "Needed an urgent reply",
            distractionSourceIDs: [slack.id]
        )
        store.review(blockID: block.id, review: review)

        XCTAssertEqual(store.completedBlocks.single?.review, review)
        XCTAssertEqual(store.completedBlocks.single?.review?.distractionSourceIDs, [slack.id])
    }

    func testNoInputTimeIsRetainedAsEvidenceButExcludedFromObservedActivity() throws {
        let start = date("2026-09-12T09:00:00Z")
        let source = FocusActivitySource(appName: "Notes")
        var store = FocusDataStore()

        store.start(intention: "Read research", source: source, at: start, timeZone: .gmt)
        store.recordNoInput(since: date("2026-09-12T09:05:00Z"), at: date("2026-09-12T09:10:00Z"))
        store.recordNoInput(since: date("2026-09-12T09:05:00Z"), at: date("2026-09-12T09:11:00Z"))
        store.record(source: source, at: date("2026-09-12T09:12:00Z"))
        let block = try XCTUnwrap(store.finish(at: date("2026-09-12T09:20:00Z")))

        XCTAssertEqual(block.observedDuration, 780)
        XCTAssertEqual(block.noInputDuration, 360)
        XCTAssertEqual(block.gaps.single?.reason, .noInput)
    }

    func testLongUnobservedGapIsNotAddedToFocusTime() throws {
        let start = date("2026-09-12T09:00:00Z")
        let source = FocusActivitySource(appName: "Xcode")
        var store = FocusDataStore()

        store.start(intention: "Implement tests", source: source, at: start, timeZone: .gmt)
        store.recordUnobservedGap(since: start, at: date("2026-09-12T09:20:00Z"))
        store.record(source: source, at: date("2026-09-12T09:20:00Z"))
        let block = try XCTUnwrap(store.finish(at: date("2026-09-12T09:25:00Z")))

        XCTAssertEqual(block.observedDuration, 300)
        XCTAssertEqual(block.gaps.single, FocusGap(reason: .unobserved, startedAt: start, endedAt: date("2026-09-12T09:20:00Z")))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

private extension TimeZone {
    static let gmt = TimeZone(secondsFromGMT: 0)!
}

private extension Array {
    var single: Element? {
        count == 1 ? first : nil
    }
}
