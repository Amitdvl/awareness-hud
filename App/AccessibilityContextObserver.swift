import ApplicationServices
import AppKit

@MainActor
final class AccessibilityContextObserver {
    var onContextChange: (() -> Void)?

    private var observer: AXObserver?
    private var observedProcessIdentifier: pid_t?

    func observe(application: NSRunningApplication) {
        let processIdentifier = application.processIdentifier
        guard observedProcessIdentifier != processIdentifier else { return }
        stop()

        guard AXIsProcessTrusted() else { return }

        let element = AXUIElementCreateApplication(processIdentifier)
        var createdObserver: AXObserver?
        guard AXObserverCreate(processIdentifier, accessibilityCallback, &createdObserver) == .success,
              let createdObserver else {
            return
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(createdObserver, element, kAXFocusedWindowChangedNotification as CFString, context)
        AXObserverAddNotification(createdObserver, element, kAXTitleChangedNotification as CFString, context)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(createdObserver), .commonModes)

        observer = createdObserver
        observedProcessIdentifier = processIdentifier
    }

    func stop() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedProcessIdentifier = nil
    }

    deinit {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }
}

private func accessibilityCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let contextObserver = Unmanaged<AccessibilityContextObserver>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async {
        contextObserver.onContextChange?()
    }
}
