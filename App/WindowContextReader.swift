import ApplicationServices
import Foundation

enum WindowContextReader {
    static func title(for processIdentifier: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }

        let application = AXUIElementCreateApplication(processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let focusedWindow else {
            return nil
        }

        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else {
            return nil
        }
        return title as? String
    }
}
