import Foundation

// MARK: - WealthBlueCardsStore
//
// Tracks "Blue" (waiting / weak-green) opportunities — cards that passed
// the green-card check but whose unrealised P/L is currently negative,
// placing them in a holding pattern until they recover.
//
// Blue cards are not eligible for AI Live or Activity until they
// transition back to strong-green status.

@MainActor
final class WealthBlueCardsStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthBlueCardsStore()
    private init() {}

    // MARK: - Published state

    /// Cards currently in the blue (waiting) lane.
    @Published private(set) var blueCards: [Opportunity] = []

    /// Time of the last blue-cards update.
    @Published private(set) var lastUpdated: Date?

    // MARK: - Public API

    /// Replace the current blue-card set with a new batch.
    ///
    /// - Parameter cards: Weak-green opportunities that should wait.
    func update(_ cards: [Opportunity]) {
        blueCards   = cards
        lastUpdated = Date()

        WealthEventLogStore.shared.record(
            title: "Blue Cards Store",
            detail: "Updated: \(cards.count) blue (waiting) cards.",
            category: "cards",
            tintName: cards.isEmpty ? "blue" : "orange",
            timestamp: .now
        )
    }

    /// Remove a specific symbol from the blue lane (e.g. after recovery).
    func remove(symbol: String) {
        blueCards.removeAll { $0.symbol == symbol }
    }

    /// Clear all blue cards (e.g. on full universe rebuild).
    func reset() {
        blueCards.removeAll()
        lastUpdated = nil
    }

    // MARK: - Queries

    /// `true` when there is at least one card in the waiting lane.
    var hasBlueCards: Bool { !blueCards.isEmpty }

    /// Return the blue card for a given symbol, or `nil` if not present.
    func card(for symbol: String) -> Opportunity? {
        blueCards.first { $0.symbol == symbol }
    }
}
