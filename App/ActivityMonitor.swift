import AppKit
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
                stopTimers()
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
    private var lastPersistedAt: Date
    private var lastRenderedDurationSecond: Int?

    private static let dailyTimeStateKey = "Awareness.DailyAppTimeState"

    init() {
        let initialDate = Date()
        dailyTimeAccumulator = DailyAppTimeAccumulator(
            now: initialDate,
            persistedState: Self.loadDailyTimeState()
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
        persistDailyTime()
    }

    private func persistDailyTime() {
        guard let data = try? JSONEncoder().encode(dailyTimeAccumulator.state) else { return }
        UserDefaults.standard.set(data, forKey: Self.dailyTimeStateKey)
        lastPersistedAt = Date()
    }

    private static func loadDailyTimeState() -> DailyAppTimeState? {
        guard let data = UserDefaults.standard.data(forKey: dailyTimeStateKey) else { return nil }
        return try? JSONDecoder().decode(DailyAppTimeState.self, from: data)
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
    let windowTitle: String?
    let browserContext: BrowserContext?
}

enum ActivityContextReader {
    static func read() -> ActivityContext {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return ActivityContext(appName: "Unknown app", windowTitle: nil, browserContext: nil)
        }

        let appName = application.localizedName ?? "Unknown app"
        let windowTitle = WindowContextReader.title(for: application.processIdentifier)
        let browserContext = BrowserContextReader.read(for: application)

        return ActivityContext(
            appName: appName,
            windowTitle: windowTitle,
            browserContext: browserContext
        )
    }
}
