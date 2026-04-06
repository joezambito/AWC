import Foundation
import Combine

@MainActor
final class WealthMarketViewCycleStore: ObservableObject {
    static let shared = WealthMarketViewCycleStore()

    @Published private(set) var cycleMarker: Date?
    @Published private(set) var reviewCandidateKeys: [String] = []
    @Published private(set) var activeCandidates: [Opportunity] = []
    @Published private(set) var activeCandidateKeys: [String] = []
    @Published private(set) var activeCandidateRanks: [String: Int] = [:]
    @Published private(set) var backgroundCandidateKeys: Set<String> = []
    @Published private(set) var totalCandidateCount = 0
    @Published private(set) var eligibleCandidateCount = 0

    private init() {}

    func syncCycle(candidates: [Opportunity], cycleMarker: Date?) {
        let orderedCandidates = candidates
        let eligibleCandidates = WealthOpportunityLaneRules.marketTopCandidates(
            from: orderedCandidates,
            limit: max(orderedCandidates.count, 100)
        )
        var seenVisibleKeys: Set<String> = []
        let visibleCandidates = eligibleCandidates.filter { candidate in
            let key = WealthOpportunityLaneRules.laneKey(candidate)
            return seenVisibleKeys.insert(key).inserted
        }.prefix(100).map { $0 }

        guard !visibleCandidates.isEmpty || activeCandidates.isEmpty else {
            self.cycleMarker = cycleMarker
            self.reviewCandidateKeys = orderedCandidates.map(WealthOpportunityLaneRules.laneKey)
            self.totalCandidateCount = orderedCandidates.count
            return
        }

        let visibleKeys = visibleCandidates.map(WealthOpportunityLaneRules.laneKey)
        let visibleRanks = visibleKeys.enumerated().reduce(into: [String: Int]()) { partialResult, entry in
            let (index, key) = entry
            partialResult[key] = index + 1
        }

        let applyCycle = { [self] in
            self.cycleMarker = cycleMarker
            self.reviewCandidateKeys = orderedCandidates.map(WealthOpportunityLaneRules.laneKey)
            self.activeCandidates = visibleCandidates
            self.activeCandidateKeys = visibleKeys
            self.activeCandidateRanks = visibleRanks
            self.backgroundCandidateKeys = Set(
                WealthOpportunityLaneRules.backgroundPool(
                    from: eligibleCandidates,
                    activeMarketKeys: Set(visibleKeys)
                ).map(WealthOpportunityLaneRules.laneKey)
            )
            self.totalCandidateCount = orderedCandidates.count
            self.eligibleCandidateCount = eligibleCandidates.count
        }

        guard cycleMarker != self.cycleMarker else {
            applyCycle()
            return
        }

        let engine = WealthEngineStore.shared
        engine.pendingMarketMaterializationTask?.cancel()
        engine.pendingMarketMaterializationTask = Task { @MainActor in
            defer { engine.pendingMarketMaterializationTask = nil }

            await Task.yield()
            guard !Task.isCancelled else { return }
            applyCycle()
        }
    }
}
