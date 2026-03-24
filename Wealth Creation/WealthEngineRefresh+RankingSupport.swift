import Foundation

extension WealthEngineRefreshRanking {
    static func makeLiveBlueprint(
        from blueprint: OpportunityBlueprint,
        previousByKey: [String: Opportunity],
        sessionState: MarketSessionState?,
        refreshTime: Date,
        externalData: WealthExternalDataStore
    ) -> OpportunityBlueprint {
        let withExternalSignal = blueprint.applyingExternalSignal(externalData.normalizedSignal(for: blueprint))
        let previous = previousByKey[wealthRefreshIdentityKey(symbol: blueprint.symbol, market: blueprint.market)]
        let sessionOpen = sessionState?.canTradeNow ?? true
        let liveQuote = WealthBrokerQuoteStore.shared.liveQuote(
            for: withExternalSignal,
            previous: previous,
            refreshTime: refreshTime,
            sessionOpen: sessionOpen
        )
        return withExternalSignal.applyingLiveQuote(liveQuote)
    }

    @MainActor
    static func dataDidChange(for current: Opportunity, comparedTo previous: Opportunity?) -> Bool {
        guard let previous else { return false }

        return current.sourceTrigger != previous.sourceTrigger ||
            current.dataOrigin != previous.dataOrigin ||
            current.sourceSummary != previous.sourceSummary ||
            current.intelligenceDriverText != previous.intelligenceDriverText ||
            current.intelligenceChannelText != previous.intelligenceChannelText ||
            current.dataQualityLabel != previous.dataQualityLabel ||
            current.optionsFlowStrength != previous.optionsFlowStrength ||
            current.darkPoolStrength != previous.darkPoolStrength ||
            current.insiderStrength != previous.insiderStrength ||
            current.filingStrength != previous.filingStrength ||
            current.earningsEventRisk != previous.earningsEventRisk ||
            current.macroEventRisk != previous.macroEventRisk
    }

    @MainActor
    static func analysisDidChange(for current: Opportunity, comparedTo previous: Opportunity?) -> Bool {
        guard let previous else { return false }

        return current.rank != previous.rank ||
            current.aiScore != previous.aiScore ||
            current.confidence != previous.confidence ||
            current.safety != previous.safety ||
            current.probabilityOfSuccess != previous.probabilityOfSuccess ||
            current.newsScore != previous.newsScore ||
            current.recommendedShares != previous.recommendedShares ||
            current.expectedProfit != previous.expectedProfit ||
            current.prospect != previous.prospect ||
            current.timeToTarget != previous.timeToTarget ||
            current.timeWindow != previous.timeWindow ||
            current.catalystBucket != previous.catalystBucket ||
            current.reviewSummary != previous.reviewSummary ||
            current.urgency != previous.urgency ||
            current.targetFitLabel != previous.targetFitLabel ||
            current.speedLabel != previous.speedLabel ||
            current.capitalFitLabel != previous.capitalFitLabel ||
            current.decisionBias != previous.decisionBias ||
            current.aggressionMode != previous.aggressionMode ||
            current.marketRegime != previous.marketRegime ||
            current.targetPressureLabel != previous.targetPressureLabel ||
            current.capitalDisciplineLabel != previous.capitalDisciplineLabel ||
            current.allocationPercent != previous.allocationPercent ||
            current.positionSizePercent != previous.positionSizePercent ||
            current.conviction != previous.conviction ||
            current.permission != previous.permission ||
            current.rotationBias != previous.rotationBias ||
            current.hungerMode != previous.hungerMode ||
            current.executionStyle != previous.executionStyle ||
            current.commandText != previous.commandText ||
            current.priorityScore != previous.priorityScore ||
            current.targetDirective != previous.targetDirective ||
            current.targetCoveragePercent != previous.targetCoveragePercent ||
            current.sourceReliabilityScore != previous.sourceReliabilityScore ||
            current.shareReliabilityScore != previous.shareReliabilityScore ||
            current.trustState != previous.trustState ||
            current.trustReason != previous.trustReason ||
            current.buyReason != previous.buyReason ||
            current.rotationReason != previous.rotationReason ||
            current.warningReason != previous.warningReason
    }
}
