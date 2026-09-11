import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = ActivityMonitor()
    private var hudController: HUDWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hudController = HUDWindowController(monitor: monitor)
        hudController?.showHUD()
    }
}
