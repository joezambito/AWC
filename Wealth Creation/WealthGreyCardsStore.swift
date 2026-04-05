import Foundation

// MARK: - WealthGreyCardsStore
//
// Tracks "Grey" (inactive / unranked) opportunities — cards that are in
// the universe but have rank == 0, meaning the engine's scoring pass did
// not assign them a market rank in the current cycle.
//
// Grey cards are not eligible for AI Live promotion or Activity admission.
// They remain available for informational display (e.g. a "watchlist" view)
// and will automatically re-enter the green or blue lanes once they receive
// a positive rank in a subsequent scan.

@MainActor
final class WealthGreyCardsStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthGreyCardsStore()
    private init() {}

    // MARK: - Published state

    /// Cards currently in the grey (unranked / inactive) lane.
    @Published private(set) var greyCards: [Opportunity] = []

    /// Time of the last grey-cards update.
    @Published private(set) var lastUpdated: Date?

    // MARK: - Public API

    /// Replace the current grey-card set with a new batch.
    ///
    /// - Parameter cards: Unranked opportunities that should sit in the grey lane.
    func update(_ cards: [Opportunity]) {
        greyCards   = cards
        lastUpdated = Date()

        WealthEventLogStore.shared.record(
            title: "Grey Cards Store",
            detail: "Updated: \(cards.count) grey (unranked) cards.",
            category: "cards",
            tintName: "gray",
            timestamp: .now
        )
    }

    /// Remove a specific symbol from the grey lane (e.g. after it receives a rank).
    func remove(symbol: String) {
        greyCards.removeAll { $0.symbol == symbol }
    }

    /// Clear all grey cards (e.g. on full universe rebuild).
    func reset() {
        greyCards.removeAll()
        lastUpdated = nil
    }

    // MARK: - Queries

    /// `true` when there is at least one card in the grey lane.
    var hasGreyCards: Bool { !greyCards.isEmpty }

    /// Return the grey card for a given symbol, or `nil` if not present.
    func card(for symbol: String) -> Opportunity? {
        greyCards.first { $0.symbol == symbol }
    }
}
