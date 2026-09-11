import XCTest
@testable import AwarenessCore

final class DurationFormatterTests: XCTestCase {
    func testFormatsSeconds() {
        XCTAssertEqual(DurationFormatter.short(35), "35s")
    }

    func testFormatsMinutesAndSeconds() {
        XCTAssertEqual(DurationFormatter.short(125), "2m 5s")
    }

    func testFormatsHoursAndMinutes() {
        XCTAssertEqual(DurationFormatter.short(3_725), "1h 2m")
    }
}
