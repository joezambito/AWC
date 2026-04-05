import Foundation

// MARK: - WealthAILiveCoordinator+Selection
//
// Selection helpers: choose the best single opportunity from the promoted
// set for display in the AI Live compact card and for order routing.

extension WealthAILiveCoordinator {

    // MARK: - Selection

    /// The highest-ranked promoted card, or `nil` if none are promoted.
    ///
    /// Tie-breaking order: rank ASC → aiScore DESC → symbol ASC.
    var primarySelection: Opportunity? {
        promotedCards
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                if $0.aiScore != $1.aiScore { return $0.aiScore > $1.aiScore }
                return $0.symbol < $1.symbol
            }
            .first
    }

    /// Return up to `limit` promoted cards, sorted by rank then AI score.
    func topSelections(limit: Int = 5) -> [Opportunity] {
        promotedCards
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return $0.aiScore > $1.aiScore
            }
            .prefix(limit)
            .map { $0 }
    }

    /// `true` when the given symbol is currently in the promoted set.
    func isPromoted(symbol: String) -> Bool {
        promotedCards.contains { $0.symbol == symbol }
    }

    /// Return the promoted card for a specific symbol, or `nil`.
    func promotedCard(for symbol: String) -> Opportunity? {
        promotedCards.first { $0.symbol == symbol }
    }
}
