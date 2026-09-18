import AppKit
import AwarenessCore

@MainActor
final class StatusMenuController: NSObject {
    private let monitor: ActivityMonitor
    private weak var hudController: HUDWindowController?
    private var commandsWindowController: CodexCommandsWindowController?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let activityItem = NSMenuItem(title: "Starting up", action: nil, keyEquivalent: "")
    private let monitoringItem = NSMenuItem(title: "Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")
    private let moveItem = NSMenuItem(title: "Move HUD", action: #selector(toggleMoveMode), keyEquivalent: "")
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
        menu.addItem(commandsItem)
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Awareness", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        update(with: monitor.narrative)
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

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
