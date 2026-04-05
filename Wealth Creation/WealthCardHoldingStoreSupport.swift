import Foundation

// MARK: - WealthCardHoldingStoreSupport
//
// Support helpers for the holding-card routing layer.
//
// `WealthCardHoldingRouter` (defined in WealthCore.swift) decides which
// lane a card belongs to based on P/L, rank, and market state.  This file
// adds query and diagnostic helpers that downstream views and audit passes
// can call without importing the full routing table.
//
// No existing routing logic is modified.

@MainActor
final class WealthCardHoldingStoreSupport {

    // MARK: Shared instance

    static let shared = WealthCardHoldingStoreSupport()
    private init() {}

    // MARK: - Lane classification helpers

    /// Returns `true` when the opportunity should be considered a confirmed
    /// holding (i.e. the symbol is present in the engine's `holdings` array).
    ///
    /// - Parameter opportunity: The opportunity to test.
    func isHeld(_ opportunity: Opportunity) -> Bool {
        WealthEngineStore.shared.holdings.contains { $0.symbol == opportunity.symbol }
    }

    /// Returns the `Holding` record for the given symbol, or `nil` if the
    /// symbol is not currently in the portfolio.
    ///
    /// - Parameter symbol: The ticker symbol to look up.
    func holding(for symbol: String) -> Holding? {
        WealthEngineStore.shared.holdings.first { $0.symbol == symbol }
    }

    // MARK: - Routing diagnostics

    /// Log a diagnostic entry summarising the current holding-card state.
    ///
    /// Useful at the end of a materialization pass to confirm the routing
    /// layer has processed the latest snapshot.
    func logRoutingDiagnostic() {
        let engine    = WealthEngineStore.shared
        let holdings  = engine.holdings
        let ranked    = engine.rankedAssets

        let heldRanked = ranked.filter { opp in
            holdings.contains { $0.symbol == opp.symbol }
        }

        WealthEventLogStore.shared.record(
            title: "Card Holding Store Support",
            detail: "holdings=\(holdings.count) | ranked=\(ranked.count) | held+ranked=\(heldRanked.count)",
            category: "cards",
            tintName: heldRanked.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }
}
