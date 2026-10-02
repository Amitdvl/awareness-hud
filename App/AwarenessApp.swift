import AppKit

@main
@MainActor
final class AwarenessApp: NSObject, NSApplicationDelegate {
    private let monitor = ActivityMonitor()
    private let launchAtLoginController = LaunchAtLoginController()
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
        launchAtLoginController.enableByDefaultIfNeeded()

        let hud = HUDWindowController()
        hudController = hud
        let statusMenu = StatusMenuController(
            monitor: monitor,
            hudController: hud,
            launchAtLoginController: launchAtLoginController
        )
        statusMenuController = statusMenu
        monitor.onNarrativeChange = { [weak hud, weak statusMenu] narrative in
            hud?.update(with: narrative)
            statusMenu?.update(with: narrative)
        }
        hud.showHUD()
        hud.update(with: monitor.narrative)
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.persistTrackedTime()
    }
}
