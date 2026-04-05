import Foundation

// MARK: - WealthBackgroundRefreshCoordinator
//
// Responds to OS background-refresh grants and the wealthEngineDidBecomeReady
// notification.  Runs a soft refresh only when data is actually stale.
//
// Fix: previously this coordinator triggered refresh(mode: .soft) immediately
// on every wealthEngineDidBecomeReady event regardless of freshness.  Because
// startup itself just downloaded the universe, that caused an immediate second
// download the moment startup completed.  The coordinator now checks
// WealthDataAliveStore before deciding what to refresh.

@MainActor
final class WealthBackgroundRefreshCoordinator {

    // MARK: Shared instance

    static let shared = WealthBackgroundRefreshCoordinator()
    private init() {
        registerForAppStateNotifications()
    }

    // MARK: - State

    private(set) var lastBackgroundRefresh: Date?
    private var isRefreshInFlight = false

    /// Minimum interval between full background refresh attempts (15 minutes).
    private let minimumRefreshInterval: TimeInterval = 15 * 60

    // MARK: - Observations

    private func registerForAppStateNotifications() {
        NotificationCenter.default.addObserver(
            forName: .wealthEngineDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performBackgroundRefreshIfNeeded()
            }
        }
    }

    // MARK: - Refresh logic

    func performBackgroundRefreshIfNeeded() async {
        guard !isRefreshInFlight else { return }

        // Throttle: don't refresh if we refreshed recently.
        if let last = lastBackgroundRefresh,
           Date().timeIntervalSince(last) < minimumRefreshInterval {
            return
        }

        // Skip entirely if universe is still fresh — startup just ran.
        // runUniverseScan() has its own cache gate, but checking here avoids
        // waking the AI + market pipeline unnecessarily right after startup.
        guard !WealthDataAliveStore.shared.isUniverseAlive ||
              !WealthDataAliveStore.shared.isAIScoresAlive else {
            WealthEventLogStore.shared.record(
                title: "Background Refresh",
                detail: "Skipped – all data layers are fresh.",
                category: "refresh",
                tintName: "blue",
                timestamp: .now
            )
            return
        }

        isRefreshInFlight = true
        defer { isRefreshInFlight = false }

        WealthEventLogStore.shared.record(
            title: "Background Refresh",
            detail: "Starting soft background refresh.",
            category: "refresh",
            tintName: "blue",
            timestamp: .now
        )

        await WealthEngineStore.shared.refresh(mode: .soft)
        lastBackgroundRefresh = Date()

        WealthEventLogStore.shared.record(
            title: "Background Refresh",
            detail: "Soft background refresh complete.",
            category: "refresh",
            tintName: "green",
            timestamp: .now
        )
    }
}
