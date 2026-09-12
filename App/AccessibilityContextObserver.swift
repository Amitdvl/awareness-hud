import ApplicationServices
import AppKit

@MainActor
final class AccessibilityContextObserver {
    var onContextChange: (() -> Void)?

    private var observer: AXObserver?
    private var observedProcessIdentifier: pid_t?
    private var observedApplication: AXUIElement?
    private var observedWindow: AXUIElement?

    func observe(application: NSRunningApplication) {
        let processIdentifier = application.processIdentifier
        if observedProcessIdentifier == processIdentifier, let observedApplication {
            observeFocusedWindow(in: observedApplication)
            return
        }
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
        AXObserverAddNotification(createdObserver, element, kAXFocusedUIElementChangedNotification as CFString, context)
        AXObserverAddNotification(createdObserver, element, kAXTitleChangedNotification as CFString, context)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(createdObserver), .commonModes)

        observer = createdObserver
        observedProcessIdentifier = processIdentifier
        observedApplication = element
        observeFocusedWindow(in: element)
    }

    func stop() {
        removeWindowNotifications()
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedProcessIdentifier = nil
        observedApplication = nil
        observedWindow = nil
    }

    deinit {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    private func observeFocusedWindow(in application: AXUIElement) {
        guard let observer, let window = focusedWindow(in: application) else { return }
        if let observedWindow, CFEqual(observedWindow, window) {
            return
        }

        removeWindowNotifications()
        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, window, kAXTitleChangedNotification as CFString, context)
        AXObserverAddNotification(observer, window, kAXSelectedChildrenChangedNotification as CFString, context)
        observedWindow = window
    }

    private func removeWindowNotifications() {
        guard let observer, let observedWindow else { return }
        AXObserverRemoveNotification(observer, observedWindow, kAXTitleChangedNotification as CFString)
        AXObserverRemoveNotification(observer, observedWindow, kAXSelectedChildrenChangedNotification as CFString)
    }

    private func focusedWindow(in application: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    fileprivate func handleAccessibilityNotification() {
        if let observedApplication {
            observeFocusedWindow(in: observedApplication)
        }
        onContextChange?()
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
        contextObserver.handleAccessibilityNotification()
    }
}
