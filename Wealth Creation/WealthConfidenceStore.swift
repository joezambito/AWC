import Foundation
import Combine

@MainActor
final class WealthConfidenceStore: ObservableObject {
    static let shared = WealthConfidenceStore()

    @Published private(set) var cards: [Opportunity] = []
    @Published private(set) var confidenceByKey: [String: Int] = [:]
    @Published private(set) var lastRefresh: Date?

    private init() {}

    func sync(cards: [Opportunity], refreshTime: Date?) {
        self.cards = cards
        confidenceByKey = Dictionary(
            uniqueKeysWithValues: cards.map { (WealthOpportunityLaneRules.laneKey($0), $0.confidence) }
        )
        lastRefresh = refreshTime
    }
}
