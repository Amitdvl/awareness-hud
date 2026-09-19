import AppKit
import AwarenessCore

final class FocusHistoryWindowController: NSWindowController {
    private let textView = NSTextView()

    init() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 620, height: 660))
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
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 660),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Awareness Focus History"
        window.contentView = scrollView
        window.minSize = NSSize(width: 460, height: 320)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(data: FocusDataStore) {
        textView.string = FocusHistoryTextFormatter.format(data)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum FocusHistoryTextFormatter {
    static func format(_ data: FocusDataStore) -> String {
        guard !data.completedBlocks.isEmpty else {
            return "No completed focus blocks yet.\n\nStart one from the Awareness menu bar item. All focus data remains local to this Mac."
        }

        let heading = "Local-only focus evidence\nLabels marked ‘distraction’ are your explicit labels; all other context is measured but unclassified.\n\n"
        return heading + data.completedBlocks.reversed().map(formatBlock).joined(separator: "\n\n")
    }

    private static func formatBlock(_ block: FocusBlock) -> String {
        let timeZone = resolvedTimeZone(for: block)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.timeZone = timeZone
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.locale = .current
        timeFormatter.timeZone = timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium

        let outcome = block.review.map { "Outcome: \(outcomeText($0.outcome))" } ?? "Outcome: not reviewed"
        let measurements = [
            "Observed: \(DurationFormatter.short(block.observedDuration))",
            "No-input: \(DurationFormatter.short(block.noInputDuration))",
            "Unobserved: \(DurationFormatter.short(block.unobservedDuration))"
        ].joined(separator: " • ")
        let sources = block.sourceDurations.map { entry in
            let role: String
            if entry.source.id == block.baselineSource.id {
                role = "baseline context"
            } else if block.review?.distractionSourceIDs.contains(entry.source.id) == true {
                role = "distraction — your label"
            } else {
                role = "unclassified context"
            }
            return "  \(entry.source.displayName): \(DurationFormatter.short(entry.duration)) — \(role)"
        }.joined(separator: "\n")
        let note = block.review?.note.map { "\nNote: \($0)" } ?? ""

        return "\(dateFormatter.string(from: block.startedAt)) • \(timeFormatter.string(from: block.startedAt))–\(timeFormatter.string(from: block.endedAt))\nIntent: \(block.intention)\n\(outcome)\n\(measurements)\n\(sources)\(note)"
    }

    private static func outcomeText(_ outcome: FocusBlockOutcome) -> String {
        switch outcome {
        case .completed: "completed"
        case .partiallyCompleted: "partially completed"
        case .notCompleted: "not completed"
        }
    }

    private static func resolvedTimeZone(for block: FocusBlock) -> TimeZone {
        TimeZone(identifier: block.timeZoneIdentifier) ?? TimeZone(secondsFromGMT: block.utcOffsetSeconds) ?? .current
    }
}
