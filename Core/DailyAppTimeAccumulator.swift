import Foundation

public struct DailyAppTimeState: Codable, Equatable, Sendable {
    public let dayStart: Date
    public let durations: [String: TimeInterval]

    public init(dayStart: Date, durations: [String: TimeInterval]) {
        self.dayStart = dayStart
        self.durations = durations
    }
}

/// Accumulates foreground time per app for the current calendar day.
///
/// The state is intentionally limited to completed totals. The currently active
/// interval is runtime-only, so relaunching Awareness never counts time while it
/// was not running.
public struct DailyAppTimeAccumulator {
    private let calendar: Calendar
    private var dayStart: Date
    private var durations: [String: TimeInterval]
    private var activeAppName: String?
    private var lastUpdatedAt: Date

    public init(
        now: Date = Date(),
        calendar: Calendar = .current,
        persistedState: DailyAppTimeState? = nil
    ) {
        self.calendar = calendar
        dayStart = calendar.startOfDay(for: now)
        if let persistedState,
           calendar.isDate(persistedState.dayStart, inSameDayAs: now) {
            durations = persistedState.durations
        } else {
            durations = [:]
        }
        lastUpdatedAt = now
    }

    @discardableResult
    public mutating func record(appName: String, at date: Date = Date()) -> TimeInterval {
        resetIfNeeded(at: date)

        let elapsed = max(0, date.timeIntervalSince(lastUpdatedAt))
        if let activeAppName, elapsed > 0 {
            durations[activeAppName, default: 0] += elapsed
        }

        activeAppName = appName
        lastUpdatedAt = date
        return durations[appName, default: 0]
    }

    public var state: DailyAppTimeState {
        DailyAppTimeState(dayStart: dayStart, durations: durations)
    }

    private mutating func resetIfNeeded(at date: Date) {
        let currentDayStart = calendar.startOfDay(for: date)
        guard currentDayStart != dayStart else { return }

        dayStart = currentDayStart
        durations = [:]
        lastUpdatedAt = currentDayStart
    }
}
