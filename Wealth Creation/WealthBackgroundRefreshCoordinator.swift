import Foundation

// MARK: - WealthBackgroundRefreshCoordinator
//
// Coordinates background app refresh requests from the OS.
// Ensures the engine performs a soft refresh when iOS/macOS wakes the app
// in the background so that market data stays reasonably fresh even when
// the app is not in the foreground.

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

    /// Minimum interval between background refresh attempts (15 minutes).
    private let minimumRefreshInterval: TimeInterval = 15 * 60

    // MARK: - App state observations

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

    /// Perform a soft background refresh if enough time has passed since
    /// the last one.  Safe to call from any context.
    func performBackgroundRefreshIfNeeded() async {
        guard !isRefreshInFlight else { return }

        if let last = lastBackgroundRefresh,
           Date().timeIntervalSince(last) < minimumRefreshInterval {
            WealthEventLogStore.shared.record(
                title: "Background Refresh",
                detail: "Skipped: last refresh was \(Int(Date().timeIntervalSince(last) / 60)) min ago.",
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
