import SwiftUI

struct OpportunityCardHighlightsView: View {
    let opportunity: Opportunity
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            cell("AI SCORE", "\(opportunity.aiScore)", tint: opportunity.scoreTint)
            cell("CONF", "\(opportunity.confidence)%", tint: opportunity.confidenceTint)
            cell("READY", opportunity.readinessSummary, tint: opportunity.cardSignalTint)
            cell("CARD", opportunity.cardSignalLabel, tint: opportunity.cardSignalTint)
            cell("ENTRY", opportunity.permission.rawValue, tint: opportunity.permission.color)
            cell("PRICE", WealthFormat.money(opportunity.price), tint: priceTint)
            cell("EXIT", opportunity.shieldExitSummary, tint: WealthTheme.red)
            cell("EXP %", wealthPercentMoveText(opportunity.expectedNetReturnPercent), tint: wealthPercentMoveTint(opportunity.expectedNetReturnPercent))
            cell("EXP P/L", wealthPnLText(opportunity.expectedNetProfit), tint: wealthNetExitTint(netExit: opportunity.estimatedNetExitValue, buyTotal: opportunity.trueCost))
            cell("TRADE", opportunity.tradeabilityLabel, tint: opportunity.tradeabilityTint)
            cell("ORDER", orderSummary, tint: orderTint)
            cell("TARGET", opportunity.targetDirective, tint: WealthTheme.green)
        }
    }

    private var priceTint: Color {
        switch opportunity.orderState {
        case .ready:
            return opportunity.sessionState.canTradeNow
                ? (opportunity.priceChangePercent >= 0 ? WealthTheme.green : WealthTheme.orange)
                : opportunity.sessionState.color
        default:
            return orderStateTint(opportunity.orderState)
        }
    }

    private func cell(_ label: String, _ value: String, tint: Color) -> some View {
        OpportunityCardCompactCell(label: label, value: value, tint: tint)
    }

    private var orderSummary: String {
        switch opportunity.orderState {
        case .submitted:
            return "ORDER SUBMITTED"
        case .pending:
            return "ORDER PENDING"
        case .partial:
            return "ORDER SENT"
        case .filled:
            return "ORDER FULFILLED"
        case .ready:
            return opportunity.sessionState.canTradeNow ? "ORDER SENT" : "ORDER PENDING"
        }
    }

    private var orderTint: Color {
        switch opportunity.orderState {
        case .filled:
            return WealthTheme.white
        case .ready:
            return opportunity.sessionState.canTradeNow ? WealthTheme.green : WealthTheme.gold
        default:
            return orderStateTint(opportunity.orderState)
        }
    }
}
