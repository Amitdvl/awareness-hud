import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var monitor: ActivityMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Awareness")
                .font(.headline)

            Text(monitor.snapshot.websiteHost ?? monitor.snapshot.appName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle("Monitoring", isOn: $monitor.isMonitoring)

            Divider()

            Button("Open Accessibility Settings") {
                openAccessibilitySettings()
            }

            Button("Quit Awareness") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}
