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

        let completedDay = try! XCTUnwrap(accumulator.drainCompletedDays().only)
        XCTAssertEqual(completedDay.dayStart, date("2026-09-11T00:00:00Z"))
        XCTAssertEqual(completedDay.durations, ["Safari": 10])
        XCTAssertEqual(completedDay.firstTrackedAt, date("2026-09-11T23:59:50Z"))
        XCTAssertEqual(completedDay.lastTrackedAt, date("2026-09-12T00:00:00Z"))
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

    func testPausedTimeIsNotAddedAfterMonitoringResumes() {
        let calendar = utcCalendar()
        let start = date("2026-09-12T09:00:00Z")
        var accumulator = DailyAppTimeAccumulator(now: start, calendar: calendar)

        _ = accumulator.record(appName: "Safari", at: start)
        accumulator.pause(at: date("2026-09-12T09:10:00Z"))
        XCTAssertEqual(accumulator.record(appName: "Safari", at: date("2026-09-12T10:00:00Z")), 600)
    }

    func testLegacyDailyStateDecodesWithoutHistoryMetadata() throws {
        let legacyJSON = #"{"dayStart":811458000,"durations":{"Notes":60}}"#
        let state = try JSONDecoder().decode(DailyAppTimeState.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(state.durations, ["Notes": 60])
        XCTAssertNil(state.firstTrackedAt)
        XCTAssertNil(state.lastTrackedAt)
    }

    func testHistoryKeepsOneRecordPerDayAndReplacesNewerTotals() {
        let calendar = utcCalendar()
        let first = DailyAppTimeState(
            dayStart: date("2026-09-11T00:00:00Z"),
            timeZoneIdentifier: "UTC",
            utcOffsetSeconds: 0,
            durations: ["Safari": 60],
            firstTrackedAt: date("2026-09-11T09:00:00Z"),
            lastTrackedAt: date("2026-09-11T09:01:00Z")
        )
        let replacement = DailyAppTimeState(
            dayStart: first.dayStart,
            timeZoneIdentifier: "UTC",
            utcOffsetSeconds: 0,
            durations: ["Safari": 120],
            firstTrackedAt: first.firstTrackedAt,
            lastTrackedAt: date("2026-09-11T09:02:00Z")
        )
        let second = DailyAppTimeState(dayStart: date("2026-09-12T00:00:00Z"), durations: ["Notes": 30])

        var history = DailyUsageHistory(days: [second, first])
        history.upsert(replacement)

        XCTAssertEqual(history.days, [replacement, second])
        XCTAssertEqual(history.state(for: date("2026-09-11T20:00:00Z"), calendar: calendar), replacement)
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

private extension Array {
    var only: Element? {
        count == 1 ? first : nil
    }
}
