import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    enum State {
        case enabled
        case requiresApproval
        case disabled
    }

    private let preferenceKey = "Awareness.OpenAtStartup"

    var state: State {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    func enableByDefaultIfNeeded() {
        guard UserDefaults.standard.object(forKey: preferenceKey) == nil else { return }
        _ = setEnabled(true)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: preferenceKey)
            return true
        } catch {
            return false
        }
    }
}
