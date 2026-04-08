import SwiftUI
import Combine
import LocalAuthentication

@MainActor
final class WealthAuthStore: ObservableObject {
    static let shared = WealthAuthStore()

    @Published private(set) var isUnlocked = false

    private let passcodeKey = "awc_root_passcode"

    private init() {}

    func unlockWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        let reason = "Unlock Autonomous Wealth Creation to access your trading dashboard."

        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
                if success {
                    isUnlocked = true
                }
                return success
            }

            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason
                )
                if success {
                    isUnlocked = true
                }
                return success
            }
        } catch {
            return false
        }

        return false
    }

    func authenticateForReset() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Verify your identity to reset your Autonomous Wealth Creation passcode."
            )
        } catch {
            return false
        }
    }

    func verify(passcode: String) -> Bool {
        normalized(passcode) == storedPasscode
    }

    func unlockWithPasscode(_ passcode: String) -> Bool {
        let cleanPasscode = normalized(passcode)
        guard cleanPasscode.count == 6 else { return false }

        if storedPasscode == nil {
            UserDefaults.standard.set(cleanPasscode, forKey: passcodeKey)
            isUnlocked = true
            return true
        }

        let success = cleanPasscode == storedPasscode
        if success {
            isUnlocked = true
        }
        return success
    }

    func changePasscode(current: String, new: String) -> Bool {
        let cleanCurrent = normalized(current)
        let cleanNew = normalized(new)

        guard verify(passcode: cleanCurrent), cleanNew.count == 6 else {
            return false
        }

        UserDefaults.standard.set(cleanNew, forKey: passcodeKey)
        return true
    }

    func resetPasscode(_ new: String) {
        let cleanNew = normalized(new)
        guard cleanNew.count == 6 else { return }
        UserDefaults.standard.set(cleanNew, forKey: passcodeKey)
    }

    func lock() {
        isUnlocked = false
    }

    private var storedPasscode: String? {
        let saved = normalized(UserDefaults.standard.string(forKey: passcodeKey) ?? "")
        return saved.count == 6 ? saved : nil
    }

    private func normalized(_ passcode: String) -> String {
        String(passcode.filter(\.isNumber).prefix(6))
    }
}
