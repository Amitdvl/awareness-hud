import AppKit
import ApplicationServices
import AwarenessCore
import Foundation

@MainActor
final class ActivityMonitor {
    var isMonitoring = true {
        didSet {
            if isMonitoring {
                startTimers()
                refreshContext()
            } else {
                dailyTimeAccumulator.pause(at: Date())
                persistDailyTime()
                stopTimers()
                clearVisibleContext()
            }
        }
    }

    private(set) var snapshot: ActivitySnapshot
    private(set) var narrative: NarrativeContent
    var onNarrativeChange: ((NarrativeContent) -> Void)?

    private let narrativeBuilder = NarrativeBuilder()
    private var browserPollTimer: Timer?
    private var heartbeatTimer: DispatchSourceTimer?
    private let accessibilityObserver = AccessibilityContextObserver()
    private var workspaceObserver: NSObjectProtocol?
    private var previousIdentity: ActivityIdentity?
    private var activityStartedAt = Date()
    private var contextSwitchCount = 0
    private var dailyTimeAccumulator: DailyAppTimeAccumulator
    private var usageHistory: DailyUsageHistory
    private var focusData: FocusDataStore
    private var latestTrackableFocusSource: FocusActivitySource?
    private var lastFocusEvidenceAt: Date?
    private var lastPersistedAt: Date
    private var lastRenderedDurationSecond: Int?

    private static let dailyTimeStateKey = "Awareness.DailyAppTimeState"
    private static let usageHistoryKey = "Awareness.DailyUsageHistory"
    private static let focusDataKey = "Awareness.FocusData"

    init() {
        let initialDate = Date()
        let persistedHistory = Self.loadUsageHistory()
        usageHistory = persistedHistory
        focusData = Self.loadFocusData()
        focusData.resume(at: initialDate)
        lastFocusEvidenceAt = initialDate
        dailyTimeAccumulator = DailyAppTimeAccumulator(
            now: initialDate,
            persistedState: persistedHistory.state(for: initialDate, calendar: .current)
        )
        lastPersistedAt = initialDate
        let initialSnapshot = ActivitySnapshot(
            appName: "Starting up",
            activityStartedAt: initialDate,
            contextSwitchCount: 0,
            capturedAt: initialDate
        )
        snapshot = initialSnapshot
        narrative = narrativeBuilder.build(from: initialSnapshot, at: initialDate)

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshContext()
            }
        }
        accessibilityObserver.onContextChange = { [weak self] in
            self?.refreshContext()
        }
        startTimers()
        refreshContext()
    }

    deinit {
        browserPollTimer?.invalidate()
        heartbeatTimer?.cancel()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    private func startTimers() {
        guard heartbeatTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now(),
            repeating: .milliseconds(250),
            leeway: .milliseconds(25)
        )
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.updateNarrative()
            }
        }
        heartbeatTimer = timer
        timer.resume()
    }

    private func stopTimers() {
        browserPollTimer?.invalidate()
        browserPollTimer = nil
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        accessibilityObserver.stop()
    }

    private func clearVisibleContext() {
        let now = Date()
        previousIdentity = nil
        snapshot = ActivitySnapshot(
            appName: "Monitoring paused",
            activityStartedAt: now,
            contextSwitchCount: contextSwitchCount,
            capturedAt: now
        )
        lastRenderedDurationSecond = nil
        narrative = narrativeBuilder.paused()
        onNarrativeChange?(narrative)
    }

    private func updateBrowserPolling(for context: ActivityContext) {
        let isBrowserActive = context.browserContext != nil
        if isBrowserActive, browserPollTimer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshContext()
                }
            }
            timer.tolerance = 0.1
            browserPollTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else if !isBrowserActive {
            browserPollTimer?.invalidate()
            browserPollTimer = nil
        }
    }

    private func refreshContext() {
        guard isMonitoring else { return }

        let context = ActivityContextReader.read()
        let capturedAt = Date()
        let accumulatedDuration = dailyTimeAccumulator.record(appName: context.appName, at: capturedAt)
        let focusSource = focusSource(for: context)
        if let focusSource {
            latestTrackableFocusSource = focusSource
        }
        recordFocusEvidence(source: focusSource, at: capturedAt)
        persistDailyTime()
        if let application = NSWorkspace.shared.frontmostApplication {
            accessibilityObserver.observe(application: application)
        }
        let identity = ActivityIdentity(
            appName: context.appName,
            windowTitle: context.windowTitle,
            websiteURL: context.browserContext?.url,
            websiteTitle: context.browserContext?.title
        )

        updateBrowserPolling(for: context)
        if previousIdentity == identity {
            return
        }

        if previousIdentity != nil {
            contextSwitchCount += 1
            activityStartedAt = Date()
        }
        previousIdentity = identity

        snapshot = ActivitySnapshot(
            appName: context.appName,
            windowTitle: context.windowTitle,
            browserName: context.browserContext?.browserName,
            websiteTitle: context.browserContext?.title,
            websiteHost: context.browserContext?.host,
            websiteURL: context.browserContext?.url,
            activityStartedAt: activityStartedAt,
            accumulatedDuration: accumulatedDuration,
            contextSwitchCount: contextSwitchCount,
            capturedAt: capturedAt
        )
        lastRenderedDurationSecond = Int(accumulatedDuration.rounded(.down))
        narrative = narrativeBuilder.build(from: snapshot, at: capturedAt)
        onNarrativeChange?(narrative)
    }

    private func updateNarrative() {
        guard isMonitoring else { return }
        let now = Date()
        snapshot.accumulatedDuration = dailyTimeAccumulator.record(appName: snapshot.appName, at: now)
        recordFocusEvidence(source: latestTrackableFocusSource, at: now)
        if now.timeIntervalSince(lastPersistedAt) >= 30 {
            persistDailyTime()
        }
        let renderedDurationSecond = Int(snapshot.accumulatedDuration.rounded(.down))
        guard renderedDurationSecond != lastRenderedDurationSecond else { return }
        lastRenderedDurationSecond = renderedDurationSecond
        let nextNarrative = narrativeBuilder.build(from: snapshot, at: now)
        if nextNarrative != narrative {
            narrative = nextNarrative
            onNarrativeChange?(narrative)
        }
    }

    func persistTrackedTime() {
        persistDailyTime(flushingAt: Date())
    }

    func usageHistorySnapshot() -> DailyUsageHistory {
        persistDailyTime(flushingAt: Date())
        return usageHistory
    }

    var hasActiveFocusBlock: Bool {
        focusData.hasActiveBlock
    }

    var activeFocusIntention: String? {
        focusData.activeIntention
    }

    @discardableResult
    func startFocusBlock(intention: String) -> Bool {
        let trimmedIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIntention.isEmpty,
              !focusData.hasActiveBlock,
              let source = latestTrackableFocusSource else {
            return false
        }
        focusData.start(intention: trimmedIntention, source: source)
        lastFocusEvidenceAt = Date()
        persistFocusData()
        return true
    }

    func finishFocusBlock() -> FocusBlock? {
        let block = focusData.finish()
        lastFocusEvidenceAt = nil
        persistFocusData()
        return block
    }

    func reviewFocusBlock(_ blockID: UUID, review: FocusBlockReview) {
        focusData.review(blockID: blockID, review: review)
        persistFocusData()
    }

    func focusHistorySnapshot() -> FocusDataStore {
        persistFocusData()
        return focusData
    }

    private func persistDailyTime(flushingAt date: Date? = nil) {
        if let date {
            dailyTimeAccumulator.flush(at: date)
        }
        dailyTimeAccumulator.drainCompletedDays().forEach { usageHistory.upsert($0) }
        usageHistory.upsert(dailyTimeAccumulator.state)

        guard let data = try? JSONEncoder().encode(usageHistory) else { return }
        UserDefaults.standard.set(data, forKey: Self.usageHistoryKey)
        // The original one-day format is migrated only after it has been archived.
        UserDefaults.standard.removeObject(forKey: Self.dailyTimeStateKey)
        lastPersistedAt = Date()
        persistFocusData()
    }

    private func persistFocusData() {
        guard let data = try? JSONEncoder().encode(focusData) else { return }
        UserDefaults.standard.set(data, forKey: Self.focusDataKey)
    }

    private static func loadUsageHistory() -> DailyUsageHistory {
        if let data = UserDefaults.standard.data(forKey: usageHistoryKey),
           let history = try? JSONDecoder().decode(DailyUsageHistory.self, from: data) {
            return history
        }

        if let data = UserDefaults.standard.data(forKey: dailyTimeStateKey),
           let legacyState = try? JSONDecoder().decode(DailyAppTimeState.self, from: data) {
            return DailyUsageHistory(days: [legacyState])
        }

        return DailyUsageHistory()
    }

    private static func loadFocusData() -> FocusDataStore {
        guard let data = UserDefaults.standard.data(forKey: focusDataKey),
              let focusData = try? JSONDecoder().decode(FocusDataStore.self, from: data) else {
            return FocusDataStore()
        }
        return focusData
    }

    private func focusSource(for context: ActivityContext) -> FocusActivitySource? {
        guard context.bundleIdentifier != "com.amitdvl.Awareness" else { return nil }
        return FocusActivitySource(
            appName: context.appName,
            browserName: context.browserContext?.browserName,
            websiteHost: context.browserContext?.host
        )
    }

    private func recordFocusEvidence(source: FocusActivitySource?, at date: Date) {
        guard focusData.hasActiveBlock else { return }
        if let lastFocusEvidenceAt, date.timeIntervalSince(lastFocusEvidenceAt) > 10 {
            focusData.recordUnobservedGap(since: lastFocusEvidenceAt, at: date)
        }
        if let lastInputAt = NoInputDetector.lastInputDate(at: date) {
            focusData.recordNoInput(since: lastInputAt, at: date)
        } else if let source {
            focusData.record(source: source, at: date)
        }
        lastFocusEvidenceAt = date
    }
}

private struct ActivityIdentity: Equatable {
    let appName: String
    let windowTitle: String?
    let websiteURL: String?
    let websiteTitle: String?
}

struct ActivityContext {
    let appName: String
    let bundleIdentifier: String?
    let windowTitle: String?
    let browserContext: BrowserContext?
}

enum ActivityContextReader {
    static func read() -> ActivityContext {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return ActivityContext(appName: "Unknown app", bundleIdentifier: nil, windowTitle: nil, browserContext: nil)
        }

        let appName = application.localizedName ?? "Unknown app"
        let windowTitle = WindowContextReader.title(for: application.processIdentifier)
        let browserContext = BrowserContextReader.read(for: application)

        return ActivityContext(
            appName: appName,
            bundleIdentifier: application.bundleIdentifier,
            windowTitle: windowTitle,
            browserContext: browserContext
        )
    }
}

private enum NoInputDetector {
    private static let threshold: TimeInterval = 60

    static func lastInputDate(at date: Date) -> Date? {
        let inputEvents: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .mouseMoved, .scrollWheel]
        guard let secondsSinceInput = inputEvents
            .map({ CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) })
            .min() else {
            return nil
        }
        guard secondsSinceInput.isFinite, secondsSinceInput >= threshold else { return nil }
        return date.addingTimeInterval(-TimeInterval(secondsSinceInput))
    }
}
