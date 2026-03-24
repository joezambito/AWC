import Foundation

extension OpportunityBlueprint {
    func applyingExternalSignal(_ signal: WealthNormalizedExternalSignal) -> OpportunityBlueprint {
        copy(
            optionsFlowStrength: max(optionsFlowStrength, signal.optionsFlowStrength),
            darkPoolStrength: max(darkPoolStrength, signal.darkPoolStrength),
            insiderStrength: max(insiderStrength, signal.insiderStrength),
            filingStrength: max(filingStrength, signal.filingStrength),
            earningsEventRisk: max(earningsEventRisk, signal.earningsEventRisk),
            macroEventRisk: max(macroEventRisk, signal.macroEventRisk)
        )
    }

    func applyingLiveQuote(_ quote: WealthLiveQuote) -> OpportunityBlueprint {
        copy(
            price: quote.price,
            priceChangePercent: quote.changePercent,
            dataAge: quote.dataAge
        )
    }

    private func copy(
        price: Double? = nil,
        priceChangePercent: Double? = nil,
        optionsFlowStrength: Double? = nil,
        darkPoolStrength: Double? = nil,
        insiderStrength: Double? = nil,
        filingStrength: Double? = nil,
        earningsEventRisk: Double? = nil,
        macroEventRisk: Double? = nil,
        dataAge: TimeInterval? = nil
    ) -> OpportunityBlueprint {
        OpportunityBlueprint(
            symbol: symbol,
            market: market,
            sector: sector,
            price: price ?? self.price,
            technical: technical,
            fundamental: fundamental,
            alternative: alternative,
            social: social,
            institutional: institutional,
            catalyst: catalyst,
            sectorFlow: sectorFlow,
            risk: risk,
            probability: probability,
            timeToTarget: timeToTarget,
            prospect: prospect,
            timeWindow: timeWindow,
            catalystBucket: catalystBucket,
            sourceTrigger: sourceTrigger,
            dataOrigin: dataOrigin,
            sourceSummary: sourceSummary,
            reviewSummary: reviewSummary,
            intelligenceDrivers: intelligenceDrivers,
            intelligenceChannels: intelligenceChannels,
            urgency: urgency,
            priceChangePercent: priceChangePercent ?? self.priceChangePercent,
            targetFitLabel: targetFitLabel,
            speedLabel: speedLabel,
            capitalFitLabel: capitalFitLabel,
            dataQualityLabel: dataQualityLabel,
            optionsFlowStrength: optionsFlowStrength ?? self.optionsFlowStrength,
            darkPoolStrength: darkPoolStrength ?? self.darkPoolStrength,
            insiderStrength: insiderStrength ?? self.insiderStrength,
            filingStrength: filingStrength ?? self.filingStrength,
            averageDailyDollarVolume: averageDailyDollarVolume,
            spreadBps: spreadBps,
            slippageRisk: slippageRisk,
            earningsEventRisk: earningsEventRisk ?? self.earningsEventRisk,
            macroEventRisk: macroEventRisk ?? self.macroEventRisk,
            newsScore: newsScore,
            analysisAge: analysisAge,
            dataAge: dataAge ?? self.dataAge,
            orderState: orderState,
            submittedPriceOffset: submittedPriceOffset,
            id: id
        )
    }
}
