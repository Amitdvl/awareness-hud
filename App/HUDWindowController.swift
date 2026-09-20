import AppKit
import AwarenessCore

final class HUDWindowController: NSWindowController, NSWindowDelegate {
    private let positionDefaultsKey = "Awareness.HUDPosition"
    private let topLeftAnchor = "topLeft"
    private var latestNarrative: NarrativeContent?
    private var hasAppliedInitialPosition = false
    private var isApplyingInitialPosition = false

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
        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showHUD() {
        guard let window else { return }
        window.orderFrontRegardless()
    }

    func update(with narrative: NarrativeContent) {
        latestNarrative = narrative
        render()
    }

    private func render() {
        guard let window,
              let contentView = window.contentView as? HUDContentView,
              let latestNarrative else { return }
        let size = contentView.update(with: latestNarrative)
        if !hasAppliedInitialPosition {
            applyInitialPosition(to: window, size: size)
            return
        }

        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        let frame = NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
        window.setFrame(frame, display: true)
    }

    func setMoveMode(_ enabled: Bool) {
        window?.ignoresMouseEvents = !enabled
        window?.isMovableByWindowBackground = enabled
    }

    func windowDidMove(_ notification: Notification) {
        guard hasAppliedInitialPosition, !isApplyingInitialPosition, let frame = window?.frame else { return }
        UserDefaults.standard.set([
            "x": NSNumber(value: Double(frame.minX)),
            "y": NSNumber(value: Double(frame.maxY)),
            "anchor": topLeftAnchor
        ], forKey: positionDefaultsKey)
        UserDefaults.standard.synchronize()
    }

    private func savedOrigin(for size: NSSize) -> NSPoint? {
        guard let saved = UserDefaults.standard.dictionary(forKey: positionDefaultsKey),
              let x = (saved["x"] as? NSNumber)?.doubleValue,
              let y = (saved["y"] as? NSNumber)?.doubleValue else {
            return nil
        }

        // The original format represented the lower-left corner. Preserve it on
        // first launch after upgrading, then persist all later deliberate moves
        // against the top edge so a future content-height change cannot drift it.
        let origin: NSPoint
        if saved["anchor"] as? String == topLeftAnchor {
            origin = NSPoint(x: x, y: y - size.height)
        } else {
            origin = NSPoint(x: x, y: y)
        }
        // Do not reject a saved point during launch. At this point AppKit can
        // report an incomplete screen inventory for an accessory app, which
        // caused perfectly valid placements to be silently replaced by the
        // default top-centre position.
        return origin
    }

    private func applyInitialPosition(to window: NSWindow, size: NSSize) {
        isApplyingInitialPosition = true
        defer {
            isApplyingInitialPosition = false
            hasAppliedInitialPosition = true
        }

        if let savedOrigin = savedOrigin(for: size) {
            window.setFrame(NSRect(origin: savedOrigin, size: size), display: true)
        } else if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let topLeft = NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.maxY - 48
            )
            window.setFrame(NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height), display: true)
        }
    }
}
