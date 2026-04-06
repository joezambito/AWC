import Foundation

extension WealthEngineRefreshRanking {
    @MainActor
    static func rank(
        _ opportunities: [Opportunity],
        previousByKey: [String: Opportunity],
        refreshTime: Date
    ) -> [Opportunity] {
        opportunities
            .sorted(by: marketRankingOrder)
            .enumerated()
            .map { index, opportunity in
                let rankedOpportunity = opportunity.withRank(index + 1)
                let previous = previousByKey[refreshIdentityKey(for: rankedOpportunity)]
                let analysisTimestamp = analysisDidChange(for: rankedOpportunity, comparedTo: previous)
                    ? refreshTime
                    : (previous?.analysisTimestamp ?? rankedOpportunity.analysisTimestamp)
                let dataTimestamp = dataDidChange(for: rankedOpportunity, comparedTo: previous)
                    ? refreshTime
                    : (previous?.dataTimestamp ?? rankedOpportunity.dataTimestamp)

                return rankedOpportunity.replacingRankContext(
                    rank: rankedOpportunity.rank,
                    analysisTimestamp: analysisTimestamp,
                    dataTimestamp: dataTimestamp,
                    refreshTime: refreshTime,
                    previous: previous
                )
            }
    }
}

private func refreshIdentityKey(for opportunity: Opportunity) -> String {
    wealthRefreshIdentityKey(symbol: opportunity.symbol, market: opportunity.market)
}

extension Opportunity {
    func replacingRankContext(
        rank: Int,
        analysisTimestamp: Date,
        dataTimestamp: Date,
        refreshTime: Date,
        previous: Opportunity?
    ) -> Opportunity {
        Opportunity(
            rank: rank,
            symbol: symbol,
            market: market,
            sector: sector,
            aiScore: aiScore,
            confidence: confidence,
            safety: safety,
            probabilityOfSuccess: probabilityOfSuccess,
            newsScore: newsScore,
            recommendedShares: recommendedShares,
            price: price,
            brokerFee: brokerFee,
            expectedProfit: expectedProfit,
            prospect: prospect,
            timeToTarget: timeToTarget,
            timeWindow: timeWindow,
            catalystBucket: catalystBucket,
            sourceTrigger: sourceTrigger,
            dataOrigin: dataOrigin,
            sourceSummary: sourceSummary,
            reviewSummary: reviewSummary,
            intelligenceDrivers: intelligenceDrivers,
            intelligenceChannels: intelligenceChannels,
            urgency: urgency,
            priceChangePercent: priceChangePercent,
            targetFitLabel: targetFitLabel,
            speedLabel: speedLabel,
            capitalFitLabel: capitalFitLabel,
            dataQualityLabel: dataQualityLabel,
            analysisTimestamp: analysisTimestamp,
            dataTimestamp: dataTimestamp,
            lastRefreshTimestamp: refreshTime,
            brokerName: brokerName,
            orderState: orderState,
            submittedPrice: submittedPrice,
            submittedShares: submittedShares,
            decisionBias: decisionBias,
            aggressionMode: aggressionMode,
            marketRegime: marketRegime,
            targetPressureLabel: targetPressureLabel,
            capitalDisciplineLabel: capitalDisciplineLabel,
            allocationPercent: allocationPercent,
            positionSizePercent: positionSizePercent,
            conviction: conviction,
            permission: permission,
            rotationBias: rotationBias,
            hungerMode: hungerMode,
            executionStyle: executionStyle,
            commandText: commandText,
            priorityScore: priorityScore,
            targetDirective: targetDirective,
            targetCoveragePercent: targetCoveragePercent,
            sourceReliabilityScore: sourceReliabilityScore,
            shareReliabilityScore: shareReliabilityScore,
            optionsFlowStrength: optionsFlowStrength,
            darkPoolStrength: darkPoolStrength,
            insiderStrength: insiderStrength,
            filingStrength: filingStrength,
            earningsEventRisk: earningsEventRisk,
            macroEventRisk: macroEventRisk,
            trustState: trustState,
            trustReason: trustReason,
            buyReason: buyReason,
            rotationReason: rotationReason,
            warningReason: warningReason,
            advancedSignal: advancedSignal,
            previousAiScore: previous?.aiScore,
            previousConfidence: previous?.confidence
        )
    }
}
