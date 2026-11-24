import LocalAuthentication
import Observation

/// Guards the Private category. Unlocked state lives in memory only and is
/// dropped when the app goes to the background.
@Observable
final class PrivateLock {
    private(set) var isUnlocked = false

    func unlock() async {
        // Face ID, Touch ID, or the device passcode as a fallback.
        let reason = String(localized: "Use Face ID to view these screenshots.")
        let succeeded = (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
        isUnlocked = succeeded
    }

    func lock() {
        isUnlocked = false
    }
}
