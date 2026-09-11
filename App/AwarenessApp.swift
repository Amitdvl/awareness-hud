import SwiftUI

@main
struct AwarenessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Awareness", systemImage: "eye.circle") {
            MenuBarContent(monitor: appDelegate.monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
