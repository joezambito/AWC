import Foundation

// MARK: - WealthGreenCardsStore
//
// Tracks "Green" (strong / in-profit) opportunities — cards whose
// unrealised P/L is positive and whose rank qualifies them for the
// green lane.
//
// Green cards are fully eligible for AI Live promotion and Activity
// admission.  Transitioning out of green (P/L turns negative) moves
// the card to the Blue (waiting) lane via `WealthBlueCardsStore`.

@MainActor
final class WealthGreenCardsStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthGreenCardsStore()
    private init() {}

    // MARK: - Published state

    /// Cards currently in the green (in-profit, active) lane.
    @Published private(set) var greenCards: [Opportunity] = []

    /// Time of the last green-cards update.
    @Published private(set) var lastUpdated: Date?

    // MARK: - Public API

    /// Replace the current green-card set with a new batch.
    ///
    /// - Parameter cards: Strong-positive opportunities that belong in the green lane.
    func update(_ cards: [Opportunity]) {
        greenCards  = cards
        lastUpdated = Date()

        WealthEventLogStore.shared.record(
            title: "Green Cards Store",
            detail: "Updated: \(cards.count) green (in-profit) cards.",
            category: "cards",
            tintName: cards.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }

    /// Remove a specific symbol from the green lane (e.g. after P/L turns negative).
    func remove(symbol: String) {
        greenCards.removeAll { $0.symbol == symbol }
    }

    /// Clear all green cards (e.g. on full universe rebuild).
    func reset() {
        greenCards.removeAll()
        lastUpdated = nil
    }

    // MARK: - Queries

    /// `true` when there is at least one card in the green lane.
    var hasGreenCards: Bool { !greenCards.isEmpty }

    /// Return the green card for a given symbol, or `nil` if not present.
    func card(for symbol: String) -> Opportunity? {
        greenCards.first { $0.symbol == symbol }
    }
}
