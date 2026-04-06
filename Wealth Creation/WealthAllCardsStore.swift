import Foundation

// MARK: - WealthAllCardsStore
//
// Central store that maintains the synced state of all card lanes.
//
// ── Card lanes ────────────────────────────────────────────────────────────
//
//   • allOpportunities — full ranked universe from the last scan
//   • marketCards      — ranked subset (rank > 0), capped at `marketCardLimit`
//   • activityKeys     — symbols admitted to the Activity queue
//   • holdingKeys      — symbols held in the portfolio
//   • livePickKeys     — symbols selected as AI Live picks
//
// ── Population flow ───────────────────────────────────────────────────────
//
//   1. WealthEngineStore+Materialization.materializeMarketCandidates()
//      calls sync(opportunities:activityKeys:holdingKeys:livePickKeys:refreshTime:)
//      after every market-ranking pass.
//
//   2. WealthAILiveCoordinator.evaluateCandidates() calls
//      updateLivePickKeys(_:) after the AI Live evaluation pass.
//
// ── Rank > 0 gate ─────────────────────────────────────────────────────────
//
//   `sync()` filters the full universe to `rank > 0` before writing to
//   `marketCards`.  This is the authoritative gate — the ONLY place in the
//   pipeline where rank is used to filter the card set.  AI Live, Activity,
//   and Order Restriction must NOT apply their own rank-tier gates.
//
// ── marketCardLimit ───────────────────────────────────────────────────────
//
//   The pipeline caps market cards at 100.  This keeps the in-memory
//   footprint bounded and ensures the Activity queue is populated from a
//   focused set of high-quality ranked candidates.
//
// ── Threading ─────────────────────────────────────────────────────────────
//
//   @MainActor — all mutations happen on the main thread so SwiftUI
//   `@Published` change notifications are always delivered on the main
//   queue without manual `DispatchQueue.main.async` wrappers.
//
// ── Observation ───────────────────────────────────────────────────────────
//
//   Observe `.shared` as an `ObservableObject` in SwiftUI views:
//
//     @StateObject private var allCards = WealthAllCardsStore.shared
//
//   Use `marketCards` to drive the card-list view.
//   Use `activityKeys` to drive the Activity badge count.
//   Use `livePickKeys` to highlight AI Live picks in the UI.

@MainActor
final class WealthAllCardsStore: ObservableObject {

    // MARK: - Shared instance

    static let shared = WealthAllCardsStore()
    private init() {}

    // MARK: - Configuration

    /// Maximum number of market-ranked cards kept in the store.
    ///
    /// Ranked candidates beyond this limit are discarded to keep the
    /// in-memory footprint bounded.  The materialization pipeline only
    /// produces this many ranked slots anyway.
    static let marketCardLimit: Int = 100

    // MARK: - Published state

    /// Full ranked universe from the last successful scan.
    @Published private(set) var allOpportunities: [Opportunity] = []

    /// Market-ranked subset — opportunities with `rank > 0`, capped at
    /// `marketCardLimit`.  This is the primary input for AI Live evaluation
    /// and Activity admission.
    @Published private(set) var marketCards: [Opportunity] = []

    /// Ticker symbols currently admitted to the Activity queue.
    @Published private(set) var activityKeys: [String] = []

    /// Ticker symbols of positions currently held in the portfolio.
    @Published private(set) var holdingKeys: Set<String> = []

    /// Ticker symbols of opportunities currently promoted as AI Live picks.
    @Published private(set) var livePickKeys: [String] = []

    /// Timestamp of the most recent successful data refresh.
    @Published private(set) var lastRefreshTime: Date?

    // MARK: - Sync API

    /// Replace the store's state with the latest engine output.
    ///
    /// Call this from `WealthEngineStore+Materialization` at the end of
    /// every market-ranking pass.
    ///
    /// - Parameters:
    ///   - opportunities: Full ranked universe (may include rank 0 entries).
    ///   - activityKeys:  Symbols currently admitted to Activity.
    ///   - holdingKeys:   Symbols currently in the portfolio.
    ///   - livePickKeys:  Symbols currently promoted by AI Live.
    ///   - refreshTime:   Timestamp of the triggering refresh pass.
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
            detail: "Synced: \(opportunities.count) total | \(marketCards.count) market | " +
                    "\(activityKeys.count) activity | \(livePickKeys.count) live picks.",
            category: "cards",
            tintName: marketCards.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }

    /// Update only the AI Live pick keys after an evaluation pass.
    ///
    /// Use this targeted update when only `livePickKeys` has changed
    /// so a full `sync()` (which requires re-passing all arrays) is
    /// not needed.
    ///
    /// - Parameter keys: The new set of promoted AI Live symbols.
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

    // MARK: - Queries

    /// `true` when at least one market-ranked card is available.
    var hasMarketCards: Bool { !marketCards.isEmpty }

    /// `true` when the given symbol is in the Activity queue.
    func isInActivity(symbol: String) -> Bool { activityKeys.contains(symbol) }

    /// `true` when the given symbol is currently held in the portfolio.
    func isHeld(symbol: String) -> Bool { holdingKeys.contains(symbol) }

    /// `true` when the given symbol is an AI Live pick.
    func isLivePick(symbol: String) -> Bool { livePickKeys.contains(symbol) }

    /// Return the market card for a given symbol, or `nil`.
    func marketCard(for symbol: String) -> Opportunity? {
        marketCards.first { $0.symbol == symbol }
    }
}
