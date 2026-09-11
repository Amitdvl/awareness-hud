import AppKit
import SwiftUI

final class HUDWindowController: NSWindowController {
    init(monitor: ActivityMonitor) {
        let view = AwarenessHUDView(monitor: monitor)
        let hostingView = NSHostingView(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        super.init(window: panel)
        panel.setContentSize(NSSize(width: 820, height: 150))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showHUD() {
        guard let window else { return }
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let topLeft = NSPoint(
                x: visibleFrame.midX - window.frame.width / 2,
                y: visibleFrame.maxY - 48
            )
            window.setFrameTopLeftPoint(topLeft)
        }
        window.orderFrontRegardless()
    }
}
