import SwiftUI

extension OpportunityCard {
    var collapsedDetails: some View {
        OpportunityCardCollapsedDetailsView(opportunity: opportunity)
    }
}

struct OpportunityCardCollapsedDetailsView: View {
    let opportunity: Opportunity

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if opportunity.monitorOnly {
                collapsedNote("MONITOR ONLY", opportunity.buyBlockReason, tint: WealthTheme.gold)
            }
            if let warning = opportunity.staleDataWarning {
                collapsedNote("DATA WARNING", warning, tint: WealthTheme.orange)
            }
            if let warning = opportunity.eventRiskWarning {
                collapsedNote("EVENT WARNING", warning, tint: WealthTheme.orange)
            }
            if let warning = opportunity.liquidityWarning {
                collapsedNote("LIQUIDITY", warning, tint: WealthTheme.gold)
            }

            collapsedNote("WHAT AI FOUND", opportunity.aiFoundHeadline, tint: WealthTheme.cyan)
            collapsedNote("AI DETAIL", opportunity.aiFoundDetail, tint: .white.opacity(0.92))
            collapsedNote("BLOCKERS", opportunity.blockerSummary, tint: WealthTheme.orange)
            collapsedNote("WHAT NEXT", opportunity.scoreUpgradePath, tint: WealthTheme.purple)
            collapsedNote("DECISION LINE", opportunity.buyReason, tint: .white.opacity(0.9))
            collapsedNote("RESEARCH", opportunity.sourceSummary, tint: .white.opacity(0.86))

            HStack(spacing: 8) {
                OpportunityCardCompactCell(label: "ORDER", value: orderSummary, tint: orderTint)
                OpportunityCardCompactCell(label: "SOURCE", value: opportunity.sourceTrigger, tint: WealthTheme.cyan)
            }

            HStack(spacing: 8) {
                OpportunityCardCompactCell(label: "REFRESH", value: opportunity.lastRefreshText, tint: WealthTheme.cyan)
                OpportunityCardCompactCell(label: "DATA AGE", value: opportunity.sourceAgeText, tint: WealthTheme.orange)
                OpportunityCardCompactCell(label: "NEXT TRADE", value: opportunity.nextTradingText, tint: WealthTheme.gold)
            }
        }
    }

    private func collapsedNote(_ title: String, _ text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(WealthTheme.green)
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            cardShell(cornerRadius: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WealthTheme.green.opacity(0.24), lineWidth: 1)
                )
        )
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
