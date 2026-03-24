import SwiftUI

extension WealthRootView {
    var dashboardEventTitle: String {
        if !pendingHoldings.isEmpty {
            return "\(pendingHoldings.count) SELL WAITING"
        }

        if let activeBuy = pendingBuyOpportunities.first {
            return "\(activeBuy.symbol) BUY \(activeBuy.orderState.rawValue)"
        }

        if let queued = firstQueuedOpportunity {
            return queued.sessionState.canTradeNow
                ? "\(queued.symbol) WAITING FOR TRADE"
                : "\(queued.symbol) WAITING FOR SESSION"
        }

        if !completedOpportunities.isEmpty {
            return "\(recentCompletedCount) RECENT \(recentCompletedCount == 1 ? "FILL" : "FILLS")"
        }

        return "SYSTEM STABLE"
    }

    var dashboardEventMessage: String {
        if !pendingHoldings.isEmpty {
            return "Available trading funds stay unchanged until IBKR confirms the sale and returns the final net proceeds."
        }

        if let activeBuy = pendingBuyOpportunities.first {
            return "Reserved \(WealthFormat.money(activeBuy.reservedCapital)) for \(activeBuy.symbol) while the broker confirms the fill."
        }

        if let queued = firstQueuedOpportunity {
            return queued.sessionState.canTradeNow
                ? "\(queued.symbol) is queued and waiting for the final trade send."
                : "\(queued.symbol) is queued for review when the broker session opens again."
        }

        if let completed = completedOpportunities.first {
            return "\(completed.symbol) completed at \(WealthFormat.money(completed.submittedPrice)) and can now flow into holdings or completed history."
        }

        return "No pending broker actions are blocking capital or holdings right now."
    }

    var dashboardEventTint: Color {
        if !pendingHoldings.isEmpty { return WealthTheme.purple }
        if !pendingBuyOpportunities.isEmpty { return WealthTheme.cyan }
        if firstQueuedOpportunity != nil { return WealthTheme.gold }
        if !completedOpportunities.isEmpty { return WealthTheme.white }
        return WealthTheme.green
    }

    var activityMoments: [ActivityMoment] {
        var moments: [ActivityMoment] = []

        if let pendingSell = pendingHoldings.first {
            moments.append(
                ActivityMoment(
                    id: "sell-\(pendingSell.id)",
                    title: "\(pendingSell.symbol) SELL WAITING",
                    detail: "Net \(WealthFormat.money(pendingSell.pendingNetValue)) stays out of capital until confirmed.",
                    tint: WealthTheme.purple
                )
            )
        }

        if let pendingBuy = pendingBuyOpportunities.first {
            moments.append(
                ActivityMoment(
                    id: "buy-\(pendingBuy.id)",
                    title: "\(pendingBuy.symbol) BUY RESERVED",
                    detail: "\(WealthFormat.money(pendingBuy.reservedCapital)) reserved while IBKR confirms the fill.",
                    tint: WealthTheme.cyan
                )
            )
        }

        if let queued = firstQueuedOpportunity {
            moments.append(
                ActivityMoment(
                    id: "queue-\(queued.id)",
                    title: queued.sessionState.canTradeNow ? "\(queued.symbol) WAITING TRADE" : "\(queued.symbol) WAITING OPEN",
                    detail: queued.sessionState.canTradeNow
                        ? "Queued for the final AI check before the next order is sent."
                        : "Queued for broker session review before the next order is sent.",
                    tint: WealthTheme.gold
                )
            )
        }

        if let completed = completedOpportunities.first {
            moments.append(
                ActivityMoment(
                    id: "done-\(completed.id)",
                    title: "\(completed.symbol) COMPLETED",
                    detail: "Filled at \(WealthFormat.money(completed.submittedPrice)) and moved into completed activity.",
                    tint: WealthTheme.white
                )
            )
        }

        if moments.isEmpty {
            moments.append(
                ActivityMoment(
                    id: "stable",
                    title: "NO LIVE BLOCKERS",
                    detail: "Capital, holdings, and broker state are currently stable.",
                    tint: WealthTheme.green
                )
            )
        }

        return Array(moments.prefix(2))
    }

    private var firstQueuedOpportunity: Opportunity? {
        pendingOpportunities.first(where: { $0.orderState == .ready })
    }

    func opportunitySort(_ lhs: Opportunity, _ rhs: Opportunity) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        if lhs.aiScore != rhs.aiScore { return lhs.aiScore < rhs.aiScore }
        if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
        return lhs.symbol < rhs.symbol
    }

    func activityOpportunitySort(_ lhs: Opportunity, _ rhs: Opportunity) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.symbol < rhs.symbol
    }
}
