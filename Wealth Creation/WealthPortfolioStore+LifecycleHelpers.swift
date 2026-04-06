import Foundation

// MARK: - WealthPortfolioLifecycleHelper
//
// Singleton that watches for the `wealthEngineDidBecomeReady` notification
// and triggers the post-startup Activity reconciliation pass.
//
// ── Purpose ───────────────────────────────────────────────────────────────
//
//   The Activity admission queue must be reconciled after `tradingLifecycleArmed`
//   becomes `true` on `WealthEngineStore`.  `WealthPortfolioLifecycleHelper`
//   bridges the gap between that flag being set and
//   `WealthPortfolioStore.rerunActivityAdmissionAfterStartup()` being called.
//
// ── Notification-driven trigger ───────────────────────────────────────────
//
//   The helper registers for `.wealthEngineDidBecomeReady` in its `init()`.
//   `WealthReadyStateGate` posts this notification exactly once — the first
//   time both `WealthEngineStartupController.isStartupComplete` is `true`
//   AND `markDownstreamRebuildComplete()` has been called.
//
//   When the notification fires, `handleEngineReady()` checks whether
//   `tradingLifecycleArmed` is already `true`.  If it is, the reconciliation
//   is triggered immediately.  If not (race condition — the notification
//   arrived before the flag was set), a 1-second retry loop fires up to
//   `maxRetryAttempts` times until the flag is set.
//
// ── Retry loop ────────────────────────────────────────────────────────────
//
//   `scheduleArmedRetry(attemptsRemaining:)` uses a recursive `Task.sleep`
//   pattern.  Each attempt waits 1 second before re-checking the flag.
//   With `maxRetryAttempts = 30` this gives a 30-second window before the
//   helper gives up and logs an error.
//
//   The retry Task is cancelled if `triggerAdmissionRerun()` is called
//   successfully, preventing redundant reconciliation calls.
//
// ── Threading ─────────────────────────────────────────────────────────────
//
//   The class is `@MainActor`.  The notification observer hops to
//   `@MainActor` via `Task { @MainActor in ... }`.  All accesses to
//   `WealthEngineStore.shared.tradingLifecycleArmed` and
//   `WealthPortfolioStore.shared` are therefore on the correct actor.
//
// ── Activation ────────────────────────────────────────────────────────────
//
//   Touch `WealthPortfolioLifecycleHelper.shared` during
//   `WealthNewComponentsBootstrap.activate()` to ensure the notification
//   observer is registered before the engine can post the ready notification.

@MainActor
final class WealthPortfolioLifecycleHelper {

    // MARK: - Shared instance

    static let shared = WealthPortfolioLifecycleHelper()

    // MARK: - Constants

    /// Maximum number of 1-second retry attempts before giving up.
    private let maxRetryAttempts = 30

    // MARK: - Private state

    /// Handle for the active retry task, if any.
    private var retryTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        NotificationCenter.default.addObserver(
            forName: .wealthEngineDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleEngineReady()
            }
        }
    }

    // MARK: - Private

    private func handleEngineReady() {
        if WealthEngineStore.shared.tradingLifecycleArmed {
            triggerAdmissionRerun()
        } else {
            scheduleArmedRetry(attemptsRemaining: maxRetryAttempts)
        }
    }

    private func triggerAdmissionRerun() {
        retryTask?.cancel()
        retryTask = nil
        WealthPortfolioStore.shared.rerunActivityAdmissionAfterStartup()
    }

    private func scheduleArmedRetry(attemptsRemaining: Int) {
        guard attemptsRemaining > 0 else {
            WealthEventLogStore.shared.record(
                title: "Portfolio Lifecycle",
                detail: "scheduleArmedRetry: gave up after \(maxRetryAttempts) attempts — tradingLifecycleArmed never became true.",
                category: "activity",
                tintName: "red",
                timestamp: .now
            )
            return
        }

        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            if WealthEngineStore.shared.tradingLifecycleArmed {
                self.triggerAdmissionRerun()
            } else {
                self.scheduleArmedRetry(attemptsRemaining: attemptsRemaining - 1)
            }
        }
    }
}
