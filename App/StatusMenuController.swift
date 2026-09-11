import AppKit
import AwarenessCore

@MainActor
final class StatusMenuController: NSObject {
    private let monitor: ActivityMonitor
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let activityItem = NSMenuItem(title: "Starting up", action: nil, keyEquivalent: "")
    private let monitoringItem = NSMenuItem(title: "Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")

    init(monitor: ActivityMonitor) {
        self.monitor = monitor
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

    @objc private func toggleMonitoring() {
        monitor.isMonitoring.toggle()
        monitoringItem.state = monitor.isMonitoring ? .on : .off
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
