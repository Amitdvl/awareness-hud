import AppKit
import AwarenessCore
import Foundation

@MainActor
final class ActivityMonitor {
    var isMonitoring = true {
        didSet {
            if isMonitoring {
                refreshContext()
            }
        }
    }

    private(set) var snapshot: ActivitySnapshot
    private(set) var narrative: NarrativeContent
    var onNarrativeChange: ((NarrativeContent) -> Void)?

    private let narrativeBuilder = NarrativeBuilder()
    private var contextTimer: Timer?
    private var heartbeatTimer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var previousIdentity: ActivityIdentity?
    private var activityStartedAt = Date()
    private var contextSwitchCount = 0

    init() {
        let initialDate = Date()
        let initialSnapshot = ActivitySnapshot(
            appName: "Starting up",
            activityStartedAt: initialDate,
            contextSwitchCount: 0,
            capturedAt: initialDate
        )
        snapshot = initialSnapshot
        narrative = narrativeBuilder.build(from: initialSnapshot, at: initialDate)

        contextTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshContext()
            }
        }
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateNarrative()
            }
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshContext()
            }
        }
        refreshContext()
    }

    deinit {
        contextTimer?.invalidate()
        heartbeatTimer?.invalidate()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    private func refreshContext() {
        guard isMonitoring else { return }

        let context = ActivityContextReader.read()
        let identity = ActivityIdentity(
            appName: context.appName,
            windowTitle: context.windowTitle,
            websiteURL: context.browserContext?.url,
            websiteTitle: context.browserContext?.title
        )

        if previousIdentity == identity {
            return
        }

        if previousIdentity != nil {
            contextSwitchCount += 1
            activityStartedAt = Date()
        }
        previousIdentity = identity

        let capturedAt = Date()
        snapshot = ActivitySnapshot(
            appName: context.appName,
            windowTitle: context.windowTitle,
            browserName: context.browserContext?.browserName,
            websiteTitle: context.browserContext?.title,
            websiteHost: context.browserContext?.host,
            websiteURL: context.browserContext?.url,
            activityStartedAt: activityStartedAt,
            contextSwitchCount: contextSwitchCount,
            capturedAt: capturedAt
        )
        narrative = narrativeBuilder.build(from: snapshot, at: capturedAt)
        onNarrativeChange?(narrative)
    }

    private func updateNarrative() {
        guard isMonitoring else { return }
        let nextNarrative = narrativeBuilder.build(from: snapshot, at: Date())
        if nextNarrative != narrative {
            narrative = nextNarrative
            onNarrativeChange?(narrative)
        }
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
