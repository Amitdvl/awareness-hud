import AppKit
import AwarenessCore

@MainActor
final class StatusMenuController: NSObject {
    private let monitor: ActivityMonitor
    private weak var hudController: HUDWindowController?
    private var commandsWindowController: CodexCommandsWindowController?
    private var usageHistoryWindowController: UsageHistoryWindowController?
    private var focusHistoryWindowController: FocusHistoryWindowController?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let activityItem = NSMenuItem(title: "Starting up", action: nil, keyEquivalent: "")
    private let monitoringItem = NSMenuItem(title: "Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")
    private let moveItem = NSMenuItem(title: "Move HUD", action: #selector(toggleMoveMode), keyEquivalent: "")
    private let startFocusItem = NSMenuItem(title: "Start Focus Block…", action: #selector(startFocusBlock), keyEquivalent: "")
    private let finishFocusItem = NSMenuItem(title: "Finish Focus Block…", action: #selector(finishFocusBlock), keyEquivalent: "")
    private let focusHistoryItem = NSMenuItem(title: "Focus History…", action: #selector(openFocusHistory), keyEquivalent: "")
    private let usageHistoryItem = NSMenuItem(title: "Usage History…", action: #selector(openUsageHistory), keyEquivalent: "")
    private let commandsItem = NSMenuItem(title: "Codex Commands…", action: #selector(openCommands), keyEquivalent: "")

    init(monitor: ActivityMonitor, hudController: HUDWindowController) {
        self.monitor = monitor
        self.hudController = hudController
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "eye.circle", accessibilityDescription: "Awareness")
        statusItem.button?.toolTip = "Awareness"

        activityItem.isEnabled = false
        monitoringItem.target = self
        monitoringItem.state = .on

        let menu = NSMenu()
        menu.addItem(activityItem)
        menu.addItem(.separator())
        menu.addItem(monitoringItem)
        menu.addItem(moveItem)
        menu.addItem(.separator())
        menu.addItem(startFocusItem)
        menu.addItem(finishFocusItem)
        menu.addItem(focusHistoryItem)
        menu.addItem(usageHistoryItem)
        menu.addItem(commandsItem)
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Awareness", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        update(with: monitor.narrative)
        updateFocusItems()
    }

    func update(with narrative: NarrativeContent) {
        activityItem.title = narrative.firstAccent
    }

    @objc private func toggleMoveMode() {
        let enabled = moveItem.state != .on
        hudController?.setMoveMode(enabled)
        moveItem.state = enabled ? .on : .off
        moveItem.title = enabled ? "Stop Moving HUD" : "Move HUD"
    }

    @objc private func toggleMonitoring() {
        monitor.isMonitoring.toggle()
        monitoringItem.state = monitor.isMonitoring ? .on : .off
    }

    @objc private func openCommands() {
        if commandsWindowController == nil {
            commandsWindowController = CodexCommandsWindowController()
        }
        commandsWindowController?.showCommands()
    }

    @objc private func openUsageHistory() {
        if usageHistoryWindowController == nil {
            usageHistoryWindowController = UsageHistoryWindowController()
        }
        usageHistoryWindowController?.show(history: monitor.usageHistorySnapshot())
    }

    @objc private func startFocusBlock() {
        let alert = NSAlert()
        alert.messageText = "Start a Focus Block"
        alert.informativeText = "Describe the outcome you intend to produce. Awareness will measure context switches locally; it will not decide what was distracting."
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let intentionField = NSTextField(string: "")
        intentionField.placeholderString = "Example: Draft the project brief"
        intentionField.frame.size = NSSize(width: 380, height: 24)
        alert.accessoryView = intentionField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard monitor.startFocusBlock(intention: intentionField.stringValue) else {
            showFocusError("Enter an intention, then return to an app or website before starting a focus block.")
            return
        }
        updateFocusItems()
    }

    @objc private func finishFocusBlock() {
        guard let block = monitor.finishFocusBlock() else { return }
        updateFocusItems()
        presentReview(for: block)
    }

    @objc private func openFocusHistory() {
        if focusHistoryWindowController == nil {
            focusHistoryWindowController = FocusHistoryWindowController()
        }
        focusHistoryWindowController?.show(data: monitor.focusHistorySnapshot())
    }

    private func presentReview(for block: FocusBlock) {
        let alert = NSAlert()
        alert.messageText = "Review Focus Block"
        alert.informativeText = "Observed context is data. Check only sources you personally consider distractions for this block. Leaving a source unchecked keeps it unclassified."
        alert.addButton(withTitle: "Save Review")
        alert.addButton(withTitle: "Skip Review")

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)

        let intention = NSTextField(labelWithString: "Intent: \(block.intention)")
        stack.addArrangedSubview(intention)

        let outcomePicker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 230, height: 26), pullsDown: false)
        [("Completed", FocusBlockOutcome.completed), ("Partially completed", .partiallyCompleted), ("Not completed", .notCompleted)].forEach { title, outcome in
            outcomePicker.addItem(withTitle: title)
            outcomePicker.lastItem?.representedObject = outcome.rawValue
        }
        stack.addArrangedSubview(outcomePicker)

        let noteField = NSTextField(string: "")
        noteField.placeholderString = "Optional note about what helped or got in the way"
        noteField.frame.size = NSSize(width: 420, height: 24)
        stack.addArrangedSubview(noteField)

        let sources = block.sourceDurations.filter { $0.source.id != block.baselineSource.id }.prefix(8)
        if !sources.isEmpty {
            stack.addArrangedSubview(NSTextField(labelWithString: "Mark only your distractions:"))
            for entry in sources {
                let checkbox = NSButton(
                    checkboxWithTitle: "\(entry.source.displayName) — \(DurationFormatter.short(entry.duration))",
                    target: nil,
                    action: nil
                )
                checkbox.identifier = NSUserInterfaceItemIdentifier(entry.source.id)
                stack.addArrangedSubview(checkbox)
            }
        }
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let outcome = outcomePicker.selectedItem?.representedObject
            .flatMap { $0 as? String }
            .flatMap(FocusBlockOutcome.init(rawValue:)) ?? .completed
        let labels = Set(stack.arrangedSubviews.compactMap { view -> String? in
            guard let checkbox = view as? NSButton,
                  checkbox.state == .on else { return nil }
            return checkbox.identifier?.rawValue
        })
        monitor.reviewFocusBlock(
            block.id,
            review: FocusBlockReview(outcome: outcome, note: noteField.stringValue, distractionSourceIDs: labels)
        )
    }

    private func updateFocusItems() {
        let hasActiveFocus = monitor.hasActiveFocusBlock
        startFocusItem.isEnabled = !hasActiveFocus
        finishFocusItem.isEnabled = hasActiveFocus
        finishFocusItem.title = monitor.activeFocusIntention.map { "Finish Focus: \($0)" } ?? "Finish Focus Block…"
    }

    private func showFocusError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Focus Block Not Started"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
