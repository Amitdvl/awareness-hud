import XCTest
@testable import AwarenessCore

final class DailyAppTimeAccumulatorTests: XCTestCase {
    func testReturningToAnAppKeepsItsDailyTotal() {
        let calendar = utcCalendar()
        let morning = date("2026-09-12T09:00:00Z")
        var accumulator = DailyAppTimeAccumulator(now: morning, calendar: calendar)

        XCTAssertEqual(accumulator.record(appName: "Safari", at: morning), 0)
        XCTAssertEqual(accumulator.record(appName: "Slack", at: date("2026-09-12T09:10:00Z")), 0)
        XCTAssertEqual(accumulator.record(appName: "Safari", at: date("2026-09-12T09:30:00Z")), 600)
        XCTAssertEqual(accumulator.record(appName: "Slack", at: date("2026-09-12T09:35:00Z")), 1_200)
        XCTAssertEqual(accumulator.record(appName: "Safari", at: date("2026-09-12T09:40:00Z")), 900)
    }

    func testMidnightStartsANewDailyTotal() {
        let calendar = utcCalendar()
        var accumulator = DailyAppTimeAccumulator(
            now: date("2026-09-11T23:59:50Z"),
            calendar: calendar
        )

        _ = accumulator.record(appName: "Safari", at: date("2026-09-11T23:59:50Z"))
        XCTAssertEqual(accumulator.record(appName: "Safari", at: date("2026-09-12T00:00:10Z")), 10)
        XCTAssertEqual(accumulator.state.durations, ["Safari": 10])
    }

    func testSameDayPersistedTotalsSurviveARelaunch() {
        let calendar = utcCalendar()
        let start = date("2026-09-12T09:00:00Z")
        var firstRun = DailyAppTimeAccumulator(now: start, calendar: calendar)
        _ = firstRun.record(appName: "Safari", at: start)
        _ = firstRun.record(appName: "Slack", at: date("2026-09-12T09:15:00Z"))

        var relaunched = DailyAppTimeAccumulator(
            now: date("2026-09-12T10:00:00Z"),
            calendar: calendar,
            persistedState: firstRun.state
        )

        XCTAssertEqual(relaunched.record(appName: "Safari", at: date("2026-09-12T10:00:00Z")), 900)
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
