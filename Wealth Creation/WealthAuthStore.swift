import Foundation

// MARK: - WealthAuthStore
//
// Manages authentication and session state.
// Tracks whether the user has an active authenticated session and
// surfaces the session token / expiry to downstream consumers.

@MainActor
final class WealthAuthStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthAuthStore()
    private init() {}

    // MARK: - UserDefaults keys

    private enum Keys {
        static let sessionToken  = "awc_session_token"
        static let sessionExpiry = "awc_session_expiry"
    }

    // MARK: - Published state

    /// `true` when a valid, non-expired session token is present.
    @Published private(set) var isAuthenticated: Bool = false

    /// The current session token, or `nil` if not authenticated.
    @Published private(set) var sessionToken: String?

    /// Expiry date of the current session, or `nil` if not authenticated.
    @Published private(set) var sessionExpiry: Date?

    // MARK: - Public API

    /// Store a new session token and mark the user as authenticated.
    func setSession(token: String, expiry: Date) {
        sessionToken      = token
        sessionExpiry     = expiry
        isAuthenticated   = true
        UserDefaults.standard.set(token,                             forKey: Keys.sessionToken)
        UserDefaults.standard.set(expiry.timeIntervalSince1970,      forKey: Keys.sessionExpiry)

        WealthEventLogStore.shared.record(
            title: "Auth Store",
            detail: "Session authenticated. Expires: \(expiry).",
            category: "auth",
            tintName: "green",
            timestamp: .now
        )
    }

    /// Clear the stored session and mark the user as unauthenticated.
    func clearSession() {
        sessionToken    = nil
        sessionExpiry   = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: Keys.sessionToken)
        UserDefaults.standard.removeObject(forKey: Keys.sessionExpiry)

        WealthEventLogStore.shared.record(
            title: "Auth Store",
            detail: "Session cleared.",
            category: "auth",
            tintName: "orange",
            timestamp: .now
        )
    }

    /// Restore a previously saved session from UserDefaults (call at launch).
    func restoreSession() {
        guard
            let token  = UserDefaults.standard.string(forKey: Keys.sessionToken),
            let expiryTs = UserDefaults.standard.object(forKey: Keys.sessionExpiry) as? Double
        else {
            isAuthenticated = false
            return
        }
        let expiry = Date(timeIntervalSince1970: expiryTs)
        if expiry > Date() {
            sessionToken    = token
            sessionExpiry   = expiry
            isAuthenticated = true
        } else {
            clearSession()
        }
    }
}
