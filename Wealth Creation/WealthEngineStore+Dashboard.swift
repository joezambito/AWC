import Foundation

// MARK: - WealthEngineStore+Dashboard
//
// Snapshot helpers consumed by dashboard views.  A snapshot bundles all
// currently-relevant derived state into a single value type so SwiftUI
// views do not need to observe multiple stores individually.

extension WealthEngineStore {

    // MARK: Dashboard snapshot

    struct DashboardSnapshot: Equatable {
        let refreshTime:        Date?
        let rankedAssets:       [Opportunity]
        let holdings:           [Holding]
        let totalPnL:           Double
        let tradingCapital:     Double
        let portfolioValue:     Double
        let isDashboardLoading: Bool

        static let empty = DashboardSnapshot(
            refreshTime:        nil,
            rankedAssets:       [],
            holdings:           [],
            totalPnL:           0,
            tradingCapital:     0,
            portfolioValue:     0,
            isDashboardLoading: false
        )
    }

    // MARK: - Public API

    /// Build a snapshot from the engine's current published state.
    /// This is a pure read – it does not modify any stored state.
    func makeDashboardSnapshot() -> DashboardSnapshot {
        DashboardSnapshot(
            refreshTime:        lastRefresh,
            rankedAssets:       rankedAssets,
            holdings:           holdings,
            totalPnL:           totalPnL,
            tradingCapital:     tradingCapital,
            portfolioValue:     portfolioValue,
            isDashboardLoading: isDashboardRefreshInFlight
        )
    }

    /// Emit a dashboard-did-update event to any downstream subscribers.
    /// Call after any refresh phase that changes data visible on the
    /// dashboard (universe, market ranking, holdings sync).
    func publishDashboardUpdate() {
        objectWillChange.send()
    }

    // MARK: - Refresh-in-flight state

    /// Mark the dashboard as currently loading/refreshing.
    func beginDashboardRefresh() {
        isDashboardRefreshInFlight = true
        publishDashboardUpdate()
    }

    /// Mark the dashboard refresh as complete and publish the updated state.
    func endDashboardRefresh() {
        isDashboardRefreshInFlight = false
        publishDashboardUpdate()
    }
}
