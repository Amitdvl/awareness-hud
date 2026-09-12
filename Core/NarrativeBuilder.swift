import Foundation

public struct NarrativeContent: Equatable, Sendable {
    public let prefix: String
    public let firstAccent: String
    public let middle: String
    public let secondAccent: String
    public let suffix: String

    public init(prefix: String, firstAccent: String, middle: String, secondAccent: String, suffix: String) {
        self.prefix = prefix
        self.firstAccent = firstAccent
        self.middle = middle
        self.secondAccent = secondAccent
        self.suffix = suffix
    }
}

public struct NarrativeBuilder {
    public init() {}

    public func build(from snapshot: ActivitySnapshot, at date: Date) -> NarrativeContent {
        let duration = DurationFormatter.short(snapshot.accumulatedDuration)

        if let websiteTitle = snapshot.websiteTitle,
           let websiteHost = snapshot.websiteHost,
           let browserName = snapshot.browserName {
            return NarrativeContent(
                prefix: "You’ve been on ",
                firstAccent: websiteHost,
                middle: " — \(websiteTitle) — in ",
                secondAccent: browserName,
                suffix: " for \(duration)."
            )
        }

        let window = snapshot.windowTitle.map { " — \($0)" } ?? ""
        return NarrativeContent(
            prefix: "You’ve been in ",
            firstAccent: snapshot.appName,
            middle: "\(window) for ",
            secondAccent: duration,
            suffix: "."
        )
    }
}
