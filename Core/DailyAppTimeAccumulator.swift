import Foundation

public struct DailyAppTimeState: Codable, Equatable, Sendable {
    public let dayStart: Date
    public let timeZoneIdentifier: String?
    public let utcOffsetSeconds: Int?
    public let durations: [String: TimeInterval]
    public let firstTrackedAt: Date?
    public let lastTrackedAt: Date?
    /// `false` when this day was imported from the pre-history tracker, whose
    /// aggregate totals did not include start and end timestamps.
    public let trackingBoundsAreComplete: Bool?

    public init(
        dayStart: Date,
        timeZoneIdentifier: String? = TimeZone.current.identifier,
        utcOffsetSeconds: Int? = nil,
        durations: [String: TimeInterval],
        firstTrackedAt: Date? = nil,
        lastTrackedAt: Date? = nil,
        trackingBoundsAreComplete: Bool? = true
    ) {
        self.dayStart = dayStart
        self.timeZoneIdentifier = timeZoneIdentifier
        self.utcOffsetSeconds = utcOffsetSeconds ?? TimeZone.current.secondsFromGMT(for: dayStart)
        self.durations = durations
        self.firstTrackedAt = firstTrackedAt
        self.lastTrackedAt = lastTrackedAt
        self.trackingBoundsAreComplete = trackingBoundsAreComplete
    }
}

/// A local-only archive of daily foreground-app totals.
///
/// Each entry retains the calendar-day boundary and time-zone context that were
/// in effect while that day's activity was tracked. No window titles, URLs, or
/// browser page details are included.
public struct DailyUsageHistory: Codable, Equatable, Sendable {
    public private(set) var days: [DailyAppTimeState]

    public init(days: [DailyAppTimeState] = []) {
        self.days = []
        days.forEach { upsert($0) }
    }

    public mutating func upsert(_ state: DailyAppTimeState) {
        if let index = days.firstIndex(where: { $0.dayStart == state.dayStart }) {
            days[index] = state
        } else {
            days.append(state)
        }
        days.sort { $0.dayStart < $1.dayStart }
    }

    public func state(for date: Date, calendar: Calendar) -> DailyAppTimeState? {
        days.last { calendar.isDate($0.dayStart, inSameDayAs: date) }
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
    private var timeZoneIdentifier: String?
    private var utcOffsetSeconds: Int?
    private var durations: [String: TimeInterval]
    private var activeAppName: String?
    private var lastUpdatedAt: Date
    private var firstTrackedAt: Date?
    private var lastTrackedAt: Date?
    private var trackingBoundsAreComplete: Bool
    private var completedDays: [DailyAppTimeState] = []

    public init(
        now: Date = Date(),
        calendar: Calendar = .current,
        persistedState: DailyAppTimeState? = nil
    ) {
        self.calendar = calendar
        if let persistedState,
           calendar.isDate(persistedState.dayStart, inSameDayAs: now) {
            dayStart = persistedState.dayStart
            timeZoneIdentifier = persistedState.timeZoneIdentifier ?? calendar.timeZone.identifier
            utcOffsetSeconds = persistedState.utcOffsetSeconds ?? calendar.timeZone.secondsFromGMT(for: persistedState.dayStart)
            durations = persistedState.durations
            firstTrackedAt = persistedState.firstTrackedAt
            lastTrackedAt = persistedState.lastTrackedAt
            trackingBoundsAreComplete = persistedState.trackingBoundsAreComplete ?? false
        } else {
            dayStart = calendar.startOfDay(for: now)
            timeZoneIdentifier = calendar.timeZone.identifier
            utcOffsetSeconds = calendar.timeZone.secondsFromGMT(for: dayStart)
            durations = [:]
            firstTrackedAt = nil
            lastTrackedAt = nil
            trackingBoundsAreComplete = true
        }
        lastUpdatedAt = now
    }

    @discardableResult
    public mutating func record(appName: String, at date: Date = Date()) -> TimeInterval {
        advance(to: date)
        activeAppName = appName
        if trackingBoundsAreComplete {
            firstTrackedAt = firstTrackedAt ?? date
        }
        lastTrackedAt = date
        return durations[appName, default: 0]
    }

    /// Stops timing until a later `record` call. Time through the pause is kept.
    public mutating func pause(at date: Date = Date()) {
        advance(to: date)
        activeAppName = nil
        lastUpdatedAt = date
    }

    /// Captures elapsed time without changing the active app.
    public mutating func flush(at date: Date = Date()) {
        advance(to: date)
    }

    /// Returns completed calendar days since the last drain.
    public mutating func drainCompletedDays() -> [DailyAppTimeState] {
        defer { completedDays.removeAll() }
        return completedDays
    }

    public var state: DailyAppTimeState {
        DailyAppTimeState(
            dayStart: dayStart,
            timeZoneIdentifier: timeZoneIdentifier,
            utcOffsetSeconds: utcOffsetSeconds,
            durations: durations,
            firstTrackedAt: firstTrackedAt,
            lastTrackedAt: lastTrackedAt,
            trackingBoundsAreComplete: trackingBoundsAreComplete
        )
    }

    private mutating func advance(to date: Date) {
        guard date > lastUpdatedAt else { return }

        guard let activeAppName else {
            lastUpdatedAt = date
            return
        }

        while !calendar.isDate(lastUpdatedAt, inSameDayAs: date) {
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                break
            }
            let boundary = min(nextDayStart, date)
            durations[activeAppName, default: 0] += boundary.timeIntervalSince(lastUpdatedAt)
            lastUpdatedAt = boundary
            lastTrackedAt = boundary
            completedDays.append(state)
            beginDay(at: boundary)
        }

        let elapsed = date.timeIntervalSince(lastUpdatedAt)
        if elapsed > 0 {
            durations[activeAppName, default: 0] += elapsed
        }
        lastUpdatedAt = date
        lastTrackedAt = date
    }

    private mutating func beginDay(at date: Date) {
        dayStart = calendar.startOfDay(for: date)
        timeZoneIdentifier = calendar.timeZone.identifier
        utcOffsetSeconds = calendar.timeZone.secondsFromGMT(for: dayStart)
        durations = [:]
        firstTrackedAt = date
        lastTrackedAt = date
        trackingBoundsAreComplete = true
    }
}
