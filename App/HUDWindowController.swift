import AppKit
import AwarenessCore

final class HUDWindowController: NSWindowController {
    init() {
        let contentView = HUDContentView(frame: NSRect(x: 0, y: 0, width: 520, height: 76))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        super.init(window: panel)
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

    func update(with narrative: NarrativeContent) {
        (window?.contentView as? HUDContentView)?.update(with: narrative)
    }
}
