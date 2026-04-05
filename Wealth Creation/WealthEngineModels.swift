import Foundation

// MARK: - DashboardSnapshot

/// A point-in-time snapshot of engine state for the dashboard UI.
struct DashboardSnapshot {
    var rankedAssets: [Opportunity] = []
    var scannedSignals: [MarketSignal] = []
    var lastRefresh: Date? = nil
    var capturedAt: Date = .now
}

// MARK: - PendingRefreshPayload

/// Reserved payload for a deferred refresh cycle.
struct PendingRefreshPayload {
    let mode: RefreshMode
    let requestedAt: Date
}

// MARK: - RefreshMode

enum RefreshMode {
    case soft
    case heavy
    case deep
    case startup
    case quick
}
