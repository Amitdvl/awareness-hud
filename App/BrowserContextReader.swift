import AppKit
import Foundation

struct BrowserContext: Equatable, Sendable {
    let browserName: String
    let title: String?
    let url: String?
    let host: String?
}

enum BrowserContextReader {
    private static let chromeScript = """
    tell application "Google Chrome"
        if (count of windows) = 0 then return {"", ""}
        return {URL of active tab of front window, title of active tab of front window}
    end tell
    """

    private static let safariScript = """
    tell application "Safari"
        if (count of windows) = 0 then return {"", ""}
        return {URL of front document, name of front document}
    end tell
    """

    static func read(for application: NSRunningApplication) -> BrowserContext? {
        switch application.bundleIdentifier {
        case "com.google.Chrome":
            return readChrome()
        case "com.apple.Safari":
            return readSafari()
        default:
            return nil
        }
    }

    private static func readChrome() -> BrowserContext? {
        execute(script: chromeScript, browserName: "Chrome")
    }

    private static func readSafari() -> BrowserContext? {
        execute(script: safariScript, browserName: "Safari")
    }

    private static func execute(script: String, browserName: String) -> BrowserContext? {
        var error: NSDictionary?
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(&error),
              result.numberOfItems >= 2,
              let urlDescriptor = result.atIndex(1),
              let titleDescriptor = result.atIndex(2) else {
            return nil
        }

        let rawURL = urlDescriptor.stringValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let title = titleDescriptor.stringValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let host = rawURL.flatMap { URL(string: $0)?.host }

        guard let rawURL, !rawURL.isEmpty else {
            return BrowserContext(browserName: browserName, title: title, url: nil, host: nil)
        }

        return BrowserContext(
            browserName: browserName,
            title: title?.isEmpty == true ? nil : title,
            url: rawURL,
            host: host
        )
    }
}
