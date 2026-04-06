import Foundation
import Combine

@MainActor
final class WealthDataAliveStore: ObservableObject {
    static let shared = WealthDataAliveStore()

    @Published private(set) var cards: [Opportunity] = []
    @Published private(set) var cardKeys: [String] = []
    @Published private(set) var lastRefresh: Date?

    private init() {}

    func sync(cards: [Opportunity], refreshTime: Date?) {
        self.cards = cards
        cardKeys = cards.map(WealthOpportunityLaneRules.laneKey)
        lastRefresh = refreshTime
    }

    func cachedCards(for refreshTime: Date?) -> [Opportunity]? {
        guard matches(refreshTime) else { return nil }
        return cards
    }

    private func matches(_ refreshTime: Date?) -> Bool {
        guard let lastRefresh else { return refreshTime == nil }
        guard let refreshTime else { return false }
        return abs(lastRefresh.timeIntervalSince(refreshTime)) < 0.001
    }
}
