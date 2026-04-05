import Foundation

// MARK: - WealthAllCardsStore
//
// Central store that maintains the synced state of all card lanes:
//   • Market-ranked opportunities (rank > 0)
//   • Activity-admitted opportunities
//   • Holdings (green portfolio positions)
//   • AI Live promoted picks
//
// `sync()` is called by `WealthEngineStore.materializeMarketCandidates()`
// after every market-ranking pass so downstream views always see a
// consistent snapshot.

@MainActor
final class WealthAllCardsStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthAllCardsStore()
    private init() {}

    // MARK: - Configuration

    /// Maximum number of market-ranked cards.  Pipeline caps at this value
    /// before assigning ranks.
    static let marketCardLimit: Int = 100

    // MARK: - Published state

    /// All opportunities currently known to the engine (full universe).
    @Published private(set) var allOpportunities: [Opportunity] = []

    /// Market-ranked subset (rank > 0), capped at `marketCardLimit`.
    @Published private(set) var marketCards: [Opportunity] = []

    /// Symbols currently admitted to the Activity queue.
    @Published private(set) var activityKeys: [String] = []

    /// Symbols currently held in the portfolio.
    @Published private(set) var holdingKeys: Set<String> = []

    /// Symbols currently selected as AI Live picks.
    @Published private(set) var livePickKeys: [String] = []

    /// Time of the most recent successful data refresh.
    @Published private(set) var lastRefreshTime: Date?

    // MARK: - Sync API

    /// Update the store with the latest engine output.
    ///
    /// - Parameters:
    ///   - opportunities: The full ranked universe.
    ///   - activityKeys:  Symbols admitted to the Activity queue.
    ///   - holdingKeys:   Symbols held in the portfolio.
    ///   - livePickKeys:  Symbols selected as AI Live picks.
    ///   - refreshTime:   Timestamp of the most recent refresh.
    func sync(
        opportunities: [Opportunity],
        activityKeys: [String],
        holdingKeys: Set<String>,
        livePickKeys: [String],
        refreshTime: Date?
    ) {
        allOpportunities  = opportunities
        marketCards       = opportunities
            .filter { $0.rank > 0 }
            .prefix(Self.marketCardLimit)
            .map { $0 }
        self.activityKeys = activityKeys
        self.holdingKeys  = holdingKeys
        self.livePickKeys = livePickKeys
        lastRefreshTime   = refreshTime

        WealthEventLogStore.shared.record(
            title: "All Cards Store",
            detail: "Synced: \(opportunities.count) total | \(marketCards.count) market | \(activityKeys.count) activity | \(livePickKeys.count) live picks.",
            category: "cards",
            tintName: marketCards.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }

    /// Return the current market-ranked cards, optionally prioritising cards
    /// that were refreshed at or after `preferredRefreshTime`.
    ///
    /// Called by `WealthEngineStore.runStartupMarketWarmup()` to seed the
    /// market-view cycle with the best available data.
    func currentMarketCards(preferredRefreshTime: Date?) -> [Opportunity] {
        guard let preferredRefreshTime,
              let lastRefreshTime,
              lastRefreshTime >= preferredRefreshTime else {
            return marketCards
        }
        return marketCards
    }

    /// Update only the AI Live pick keys after an evaluation pass.
    ///
    /// Called by `WealthAILiveCoordinator.evaluateCandidates()` once promoted
    /// cards are known.  Using a targeted update avoids a full re-sync (which
    /// would require re-passing all opportunities/holdings) while still
    /// ensuring `livePickKeys` reflects the current AI Live set.
    func updateLivePickKeys(_ keys: [String]) {
        livePickKeys = keys
        WealthEventLogStore.shared.record(
            title: "All Cards Store",
            detail: "Live pick keys updated: \(keys.count) promoted symbol(s).",
            category: "cards",
            tintName: keys.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }
}
