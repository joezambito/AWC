import SwiftUI

struct CompactPendingOpportunityCard: View {
    let opportunity: Opportunity
    let isExpanded: Bool
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    private var stateTint: Color { opportunity.cardSignalTint }

    private var statusText: String {
        switch opportunity.orderState {
        case .submitted:
            return "ORDER SUBMITTED"
        case .pending:
            return "ORDER PENDING"
        case .partial:
            return "ORDER SENT"
        case .filled:
            return opportunity.decisionBias == .avoid ? "SELL FILLED" : "BUY FILLED"
        case .ready:
            return opportunity.sessionState.canTradeNow ? "ORDER SENT" : "ORDER PENDING"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(opportunity.symbol)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: true, vertical: false)

                    Text("\(statusText) · \(opportunity.marketDisplayLabel)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(stateTint)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("AI \(opportunity.aiScore)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(opportunity.scoreTint)
                    Text("CONF \(opportunity.confidence)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(opportunity.confidenceTint)
                }
            }

            HStack(spacing: 8) {
                compactActivityCell("PRICE", WealthFormat.money(opportunity.price), tint: .white)
                compactActivityCell("EXIT", opportunity.shieldExitSummary, tint: WealthTheme.red)
                compactActivityCell("EXP %", wealthPercentMoveText(opportunity.projectedMovePercent), tint: wealthPercentMoveTint(opportunity.projectedMovePercent))
                compactActivityCell("EXP P/L", wealthPnLText(opportunity.expectedNetProfit), tint: wealthNetExitTint(netExit: opportunity.estimatedNetExitValue, buyTotal: opportunity.trueCost))
            }

            HStack(spacing: 8) {
                compactActivityCell("NEXT", opportunity.nextTradingText, tint: WealthTheme.gold)
                compactActivityCell("DATA", WealthFormat.age(opportunity.dataTimestamp), tint: WealthTheme.orange)
                compactActivityCell("LIVE %", wealthPercentMoveText(opportunity.liveMovePercent), tint: wealthPercentMoveTint(opportunity.liveMovePercent))
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(opportunity.aiFoundHeadline)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.cyan)
                    Text(opportunity.aiFoundDetail)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                    Text(opportunity.buyReason)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.76))
                    HStack(spacing: 8) {
                        compactActivityCell("EXIT", opportunity.shieldExitSummary, tint: WealthTheme.red)
                        compactActivityCell("NET EXIT", WealthFormat.money(opportunity.shieldExitNetValue), tint: wealthNetExitTint(netExit: opportunity.shieldExitNetValue, buyTotal: opportunity.trueCost))
                        compactActivityCell("LIVE %", wealthPercentMoveText(opportunity.liveMovePercent), tint: wealthPercentMoveTint(opportunity.liveMovePercent))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(stateTint.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
    }

    private func compactActivityCell(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundColor(tint.opacity(0.78))
            Text(value)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(cardShell(cornerRadius: 14))
    }
}
