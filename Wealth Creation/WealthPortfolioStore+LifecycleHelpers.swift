import Foundation

// MARK: - WealthPortfolioLifecycleHelper
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   `WealthPortfolioStore.rerunActivityAdmissionAfterStartup()` needs to be
//   called at the right moment: after BOTH startup is complete AND
//   `tradingLifecycleArmed` has transitioned to `true`.  Without a
//   coordinator, neither condition is reliably observed together.
//
// Solution (new code only):
//   `WealthPortfolioLifecycleHelper` observes the `wealthEngineDidBecomeReady`
//   notification and checks `tradingLifecycleArmed` at that moment.  If armed,
//   it calls `rerunActivityAdmissionAfterStartup()` immediately.  If not yet
//   armed, it schedules a one-time retry poll so the call is not lost.
//
// Integration:
//   Touch `WealthPortfolioLifecycleHelper.shared` during app bootstrap
//   (e.g. add `_ = WealthPortfolioLifecycleHelper.shared` to
//   `WealthNewComponentsBootstrap.activate()`) so the observer registers.

@MainActor
final class WealthPortfolioLifecycleHelper {

    // MARK: Shared instance

    static let shared = WealthPortfolioLifecycleHelper()

    // MARK: - Init / observer registration

    private init() {
        // Observe the engine-ready notification.
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

    private var retryTask: Task<Void, Never>?

    private func handleEngineReady() {
        if WealthPortfolioStore.shared.tradingLifecycleArmed {
            triggerAdmissionRerun()
        } else {
            // Trading lifecycle is not yet armed.  Poll once per second for
            // up to 30 seconds, then give up (the heartbeat timer will retry).
            scheduleArmedRetry(attemptsRemaining: 30)
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
                detail: "scheduleArmedRetry: gave up after 30 attempts – tradingLifecycleArmed never became true.",
                category: "activity",
                tintName: "red",
                timestamp: .now
            )
            return
        }

        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            guard !Task.isCancelled, let self else { return }
            if WealthPortfolioStore.shared.tradingLifecycleArmed {
                self.triggerAdmissionRerun()
            } else {
                self.scheduleArmedRetry(attemptsRemaining: attemptsRemaining - 1)
            }
        }
    }
}
