import Foundation

@MainActor
final class WealthPortfolioLifecycleHelper {

    // MARK: - Shared instance

    static let shared = WealthPortfolioLifecycleHelper()

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

    // MARK: - Private state

    private var retryTask: Task<Void, Never>?
    private let maxRetryAttempts = 30

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
                detail: "scheduleArmedRetry: gave up after \(maxRetryAttempts) attempts – tradingLifecycleArmed never became true.",
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
