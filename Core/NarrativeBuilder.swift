import Foundation

public struct NarrativeBuilder {
    public init() {}

    public func build(from snapshot: ActivitySnapshot) -> String {
        let duration = DurationFormatter.short(snapshot.capturedAt.timeIntervalSince(snapshot.activityStartedAt))

        if let websiteTitle = snapshot.websiteTitle,
           let websiteHost = snapshot.websiteHost,
           let browserName = snapshot.browserName {
            return "You’ve been on \(websiteHost) — \(websiteTitle) — in \(browserName) for \(duration). You’ve switched context \(snapshot.contextSwitchCount) times this session."
        }

        let window = snapshot.windowTitle.map { " — \($0)" } ?? ""
        return "You’ve been in \(snapshot.appName)\(window) for \(duration). You’ve switched context \(snapshot.contextSwitchCount) times this session."
    }
}
