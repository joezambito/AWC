import Foundation

extension WealthPortfolioStore {
    func setReservedOrderCapital(_ amount: Double) {
        reservedOrderCapital = max(0, amount)
        lastRefresh = .now
    }

    func currentSpendableCash(using holdings: [Holding], queued: [Opportunity]) -> Double {
        var spendableCash = max(0, brokerCashBalance - floorReserve)

        for holding in holdings where holding.orderIntent == .buyPending {
            spendableCash -= buyCost(for: holding.shares, price: holding.averagePrice)
        }

        for opportunity in queued {
            spendableCash -= opportunity.trueCost
        }

        return max(0, spendableCash)
    }

    func submitBuy(
        for opportunity: Opportunity,
        now: Date,
        spendableCash: inout Double
    ) -> Opportunity {
        let pendingHolding = makePendingHolding(from: opportunity, now: now)
        holdings.append(pendingHolding)
        queuedOpportunities.removeAll { $0.symbol == opportunity.symbol }
        spendableCash = max(0, spendableCash - opportunity.trueCost)

        WealthEventLogStore.shared.record(
            title: "Buy Submitted",
            detail: "\(opportunity.symbol) submitted for \(opportunity.recommendedShares) shares at \(WealthFormat.money(opportunity.submittedPrice)).",
            category: "buy",
            tintName: "green",
            timestamp: now
        )

        return opportunity.withOrderState(
            .submitted,
            submittedPrice: opportunity.submittedPrice,
            submittedShares: opportunity.recommendedShares
        )
    }

    func opportunityForHoldingState(
        _ opportunity: Opportunity,
        holding: Holding,
        filledBuys: Set<String>
    ) -> Opportunity {
        switch holding.orderIntent {
        case .buyPending:
            return opportunity.withOrderState(
                holding.orderState,
                submittedPrice: holding.averagePrice,
                submittedShares: holding.shares
            )

        case .sellPending, .live:
            if filledBuys.contains(opportunity.symbol) {
                return opportunity.withOrderState(
                    .filled,
                    submittedPrice: holding.averagePrice,
                    submittedShares: holding.shares
                )
            }
            return opportunity
        }
    }
}
