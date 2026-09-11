import Foundation

public struct ActivitySnapshot: Equatable, Sendable {
    public let appName: String
    public let windowTitle: String?
    public let browserName: String?
    public let websiteTitle: String?
    public let websiteHost: String?
    public let websiteURL: String?
    public let activityStartedAt: Date
    public let contextSwitchCount: Int
    public let capturedAt: Date

    public init(
        appName: String,
        windowTitle: String? = nil,
        browserName: String? = nil,
        websiteTitle: String? = nil,
        websiteHost: String? = nil,
        websiteURL: String? = nil,
        activityStartedAt: Date,
        contextSwitchCount: Int,
        capturedAt: Date
    ) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.browserName = browserName
        self.websiteTitle = websiteTitle
        self.websiteHost = websiteHost
        self.websiteURL = websiteURL
        self.activityStartedAt = activityStartedAt
        self.contextSwitchCount = contextSwitchCount
        self.capturedAt = capturedAt
    }
}
