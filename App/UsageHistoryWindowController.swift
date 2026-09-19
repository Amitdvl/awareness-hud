import AppKit
import AwarenessCore

final class UsageHistoryWindowController: NSWindowController {
    private let textView = NSTextView()

    init() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 620))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Awareness Usage History"
        window.contentView = scrollView
        window.minSize = NSSize(width: 420, height: 300)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(history: DailyUsageHistory) {
        textView.string = UsageHistoryTextFormatter.format(history)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum UsageHistoryTextFormatter {
    static func format(_ history: DailyUsageHistory) -> String {
        guard !history.days.isEmpty else {
            return "No foreground app time has been recorded yet.\n\nAwareness keeps this history locally on this Mac."
        }

        let heading = "Local-only history • foreground app time while Awareness runs\n\n"
        let days = history.days.reversed().map(formatDay).joined(separator: "\n\n")
        return heading + days
    }

    private static func formatDay(_ day: DailyAppTimeState) -> String {
        let timeZone = resolvedTimeZone(for: day)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.timeZone = timeZone
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.locale = .current
        timeFormatter.timeZone = timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium

        let total = day.durations.values.reduce(0, +)
        let trackedRange: String
        if day.trackingBoundsAreComplete == true,
           let firstTrackedAt = day.firstTrackedAt,
           let lastTrackedAt = day.lastTrackedAt {
            trackedRange = "Tracked \(timeFormatter.string(from: firstTrackedAt))–\(timeFormatter.string(from: lastTrackedAt))"
        } else {
            trackedRange = "Tracking bounds unavailable (collected before history was enabled)"
        }

        let zoneLabel = "\(timeZone.identifier) (UTC\(offsetText(for: timeZone, at: day.dayStart)))"
        let apps = day.durations
            .sorted { $0.value > $1.value }
            .map { "  \($0.key): \(DurationFormatter.short($0.value))" }
            .joined(separator: "\n")

        return "\(dateFormatter.string(from: day.dayStart))\n\(zoneLabel) • \(trackedRange) • \(DurationFormatter.short(total)) total\n\(apps)"
    }

    private static func resolvedTimeZone(for day: DailyAppTimeState) -> TimeZone {
        if let identifier = day.timeZoneIdentifier, let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }
        if let offset = day.utcOffsetSeconds, let timeZone = TimeZone(secondsFromGMT: offset) {
            return timeZone
        }
        return .current
    }

    private static func offsetText(for timeZone: TimeZone, at date: Date) -> String {
        let offset = timeZone.secondsFromGMT(for: date)
        let sign = offset >= 0 ? "+" : "-"
        let absoluteOffset = abs(offset)
        return String(format: "%@%02d:%02d", sign, absoluteOffset / 3_600, (absoluteOffset % 3_600) / 60)
    }
}
