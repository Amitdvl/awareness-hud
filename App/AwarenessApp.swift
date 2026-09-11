import AppKit

@main
@MainActor
final class AwarenessApp: NSObject, NSApplicationDelegate {
    private let monitor = ActivityMonitor()
    private var hudController: HUDWindowController?
    private var statusMenuController: StatusMenuController?

    static func main() {
        let application = NSApplication.shared
        let delegate = AwarenessApp()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let hud = HUDWindowController()
        hudController = hud
        statusMenuController = StatusMenuController(monitor: monitor)
        monitor.onNarrativeChange = { [weak hud] narrative in
            hud?.update(with: narrative)
        }
        hud.showHUD()
        hud.update(with: monitor.narrative)
    }
}
