import SwiftUI

struct PendingHoldingCard: View {
    let holding: Holding
    var isExpanded: Bool = false
    var usesDenseCollapsedState: Bool = false
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    private var saleStatusTint: Color {
        switch holding.orderState {
        case .partial:
            return WealthTheme.orange
        case .filled:
            return WealthTheme.white
        default:
            return WealthTheme.yellow
        }
    }

    private var saleStatusLabel: String {
        switch holding.orderState {
        case .submitted:
            return "SALE SUBMITTED"
        case .pending:
            return "SALE PENDING"
        case .partial:
            return "SALE SENT"
        case .ready:
            return "SALE PENDING"
        case .filled:
            return "SELL FILLED"
        }
    }

    var body: some View {
        let isDense = usesDenseCollapsedState && !isExpanded

        return VStack(alignment: .leading, spacing: isDense ? 6 : 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(holding.market)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    HoldingStatusIcons(shieldVisible: holding.ruleShieldVisible, surgeEnabled: protection.surgeEnabled)
                    solidPill(saleStatusLabel, color: saleStatusTint, darkText: true)
                }
            }

            HStack(spacing: 10) {
                infoCell(label: "Buy Price", value: WealthFormat.money(holding.averagePrice), tint: .white)
                infoCell(label: "Buy Total", value: WealthFormat.money(holding.buyTotalCost), tint: .white)
                infoCell(label: "Live Price", value: WealthFormat.money(holding.effectiveCurrentPrice), tint: wealthPercentMoveTint(holding.liveMovePercent))
                infoCell(label: "Exit Price", value: WealthFormat.money(holding.pendingExitPrice), tint: wealthPercentMoveTint(holding.pendingNetReturnPercent))
                infoCell(label: "LIVE %", value: wealthPercentMoveText(holding.liveMovePercent), tint: wealthPercentMoveTint(holding.liveMovePercent))
            }

            HStack(spacing: 10) {
                infoCell(label: "Sell Fee", value: WealthFormat.money(holding.pendingSellFee), tint: WealthTheme.orange)
                infoCell(label: "Sell Total", value: WealthFormat.money(holding.pendingNetValue), tint: wealthNetExitTint(netExit: holding.pendingNetValue, buyTotal: holding.pendingCostBasis))
                infoCell(label: "P / L", value: wealthPnLText(holding.pendingNetPnL), tint: wealthPnLTint(holding.pendingNetPnL))
                infoCell(label: "NET %", value: wealthPercentMoveText(holding.pendingNetReturnPercent), tint: wealthPercentMoveTint(holding.pendingNetReturnPercent))
                infoCell(label: "Plan", value: holding.predictedHoldText, tint: WealthTheme.cyan)
            }

            infoCell(label: "AI Line", value: cleanHoldingAIText(holding.aiCommentary), tint: .white)

            HStack(spacing: 10) {
                infoCell(label: "Last Refresh", value: holding.lastRefreshText, tint: WealthTheme.cyan)
                infoCell(label: "Data Age", value: WealthFormat.age(holding.dataTimestamp), tint: WealthTheme.orange)
                infoCell(label: "Next Trade", value: holding.nextTradingText, tint: WealthTheme.gold)
            }

            Text("Tap to read the full sell detail and latest confirmation status.")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.68))

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        infoCell(label: "Shares", value: "\(holding.shares)", tint: .white)
                        infoCell(label: "Pending", value: "\(holding.pendingShares)", tint: WealthTheme.yellow)
                        infoCell(label: "Pending Age", value: holding.pendingAgeText ?? "Just sent", tint: WealthTheme.cyan)
                    }

                    HStack(spacing: 10) {
                        infoCell(label: "Order", value: saleStatusLabel, tint: saleStatusTint)
                        infoCell(label: "Risk", value: holding.riskLabel, tint: riskTint(holding.riskLabel))
                    }

                    HStack(spacing: 10) {
                        infoCell(label: "Pending Basis", value: WealthFormat.money(holding.pendingCostBasis), tint: .white)
                        infoCell(label: "Pending Net", value: WealthFormat.money(holding.pendingNetValue), tint: wealthNetExitTint(netExit: holding.pendingNetValue, buyTotal: holding.pendingCostBasis))
                        infoCell(label: "NET %", value: wealthPercentMoveText(holding.pendingNetReturnPercent), tint: wealthPercentMoveTint(holding.pendingNetReturnPercent))
                    }

                    aiNarrativeCellView(label: "AI Line", value: holding.aiCommentary)
                    aiNarrativeCellView(label: "AI Review", value: holding.reviewSummary)
                    infoCell(label: "AI Signal", value: cleanHoldingAIText(holding.sourceTrigger), tint: WealthTheme.cyan)
                }
            }
        }
        .padding(isDense ? 8 : 10)
        .background(listRowShell(cornerRadius: 18, accent: WealthTheme.yellow))
        .padding(.horizontal, isDense ? 8 : 10)
    }
}
