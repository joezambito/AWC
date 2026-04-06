import Foundation
import Combine

@MainActor
final class WealthAIScoreStore: ObservableObject {
    static let shared = WealthAIScoreStore()

    @Published private(set) var cards: [Opportunity] = []
    @Published private(set) var scoresByKey: [String: Int] = [:]
    @Published private(set) var lastRefresh: Date?

    private init() {}

    func sync(cards: [Opportunity], refreshTime: Date?) {
        self.cards = cards
        scoresByKey = Dictionary(
            uniqueKeysWithValues: cards.map { (WealthOpportunityLaneRules.laneKey($0), $0.aiScore) }
        )
        lastRefresh = refreshTime
    }
}
