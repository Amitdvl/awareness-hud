import AppKit
import AwarenessCore
import Combine
import Foundation

@MainActor
final class ActivityMonitor: ObservableObject {
    @Published var isMonitoring = true {
        didSet {
            if isMonitoring {
                refresh()
            }
        }
    }

    @Published private(set) var snapshot: ActivitySnapshot

    private let narrativeBuilder = NarrativeBuilder()
    private var timer: Timer?
    private var previousIdentity: ActivityIdentity?
    private var activityStartedAt = Date()
    private var contextSwitchCount = 0

    init() {
        snapshot = ActivitySnapshot(
            appName: "Starting up",
            activityStartedAt: activityStartedAt,
            contextSwitchCount: 0,
            capturedAt: activityStartedAt
        )

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        refresh()
    }

    deinit {
        timer?.invalidate()
    }

    var narrative: String {
        narrativeBuilder.build(from: snapshot)
    }

    func refresh() {
        guard isMonitoring else { return }

        let context = ActivityContextReader.read()
        let identity = ActivityIdentity(
            appName: context.appName,
            windowTitle: context.windowTitle,
            websiteURL: context.browserContext?.url,
            websiteTitle: context.browserContext?.title
        )

        if let previousIdentity, previousIdentity != identity {
            contextSwitchCount += 1
            activityStartedAt = Date()
        } else if previousIdentity == nil {
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
            contextSwitchCount: contextSwitchCount,
            capturedAt: Date()
        )
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
