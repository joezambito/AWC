import SwiftUI

struct CurrentHoldingCard: View {
    let holding: Holding
    var isExpanded: Bool = false
    var usesDenseCollapsedState: Bool = false
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    private var rankTint: Color {
        switch holding.aiBand {
        case 1...3: return WealthTheme.green
        case 4...6: return WealthTheme.cyan
        case 7...10: return WealthTheme.gold
        default: return WealthTheme.purple
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
                    HoldingStatusIcons(shieldVisible: true, surgeEnabled: true)
                    solidPill("LIVE HOLDING", color: WealthTheme.gold, darkText: true)
                    solidPill("AI LIVE #\(holding.aiBand)", color: rankTint, darkText: rankTint != WealthTheme.cyan && rankTint != WealthTheme.purple)
                }
            }

            HStack(spacing: 10) {
                infoCell(label: "Buy Price", value: WealthFormat.money(holding.averagePrice), tint: .white)
                infoCell(label: "Buy Total", value: WealthFormat.money(holding.buyTotalCost), tint: .white)
                infoCell(label: "Live Price", value: WealthFormat.money(holding.effectiveCurrentPrice), tint: wealthPercentMoveTint(holding.liveMovePercent))
                infoCell(label: "NET %", value: wealthPercentMoveText(holding.netReturnPercent), tint: wealthPercentMoveTint(holding.netReturnPercent))
                infoCell(label: "P / L", value: wealthPnLText(holding.netPnL), tint: wealthPnLTint(holding.netPnL))
            }

            HStack(spacing: 10) {
                infoCell(label: "AI Score", value: "\(holding.aiScore)", tint: holding.scoreStyle.color)
                infoCell(label: "AI Live Rank", value: "#\(holding.aiBand)", tint: rankTint)
                infoCell(label: "Confidence", value: "\(holding.confidence)%", tint: wealthHoldingConfidenceTint(holding.confidence))
                infoCell(label: "Shares", value: "\(holding.shares)", tint: .white)
                infoCell(label: "Plan", value: holding.predictedHoldText, tint: WealthTheme.gold)
            }

            aiNarrativeCellView(label: "AI Found", value: holding.aiCommentary)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    aiNarrativeCellView(label: "AI Review", value: holding.reviewSummary)
                    infoCell(label: "AI Signal", value: cleanHoldingAIText(holding.sourceTrigger), tint: WealthTheme.cyan)
                    infoCell(label: "AI Risk", value: cleanHoldingAIText(holding.riskMatrixText), tint: WealthTheme.orange)

                    HStack(spacing: 10) {
                        infoCell(label: "Live %", value: wealthPercentMoveText(holding.liveMovePercent), tint: wealthPercentMoveTint(holding.liveMovePercent))
                        infoCell(label: "Exit Price", value: holding.shieldExitSummary, tint: wealthPercentMoveTint(holding.netReturnPercent))
                        infoCell(label: "Exit Net", value: WealthFormat.money(holding.shieldExitNetValue), tint: wealthNetExitTint(netExit: holding.shieldExitNetValue, buyTotal: holding.buyTotalCost))
                        infoCell(label: "Bought", value: holding.filledAtText, tint: WealthTheme.cyan)
                    }

                    HStack(spacing: 10) {
                        infoCell(label: "Buy Fee", value: WealthFormat.money(holding.buyFee), tint: WealthTheme.orange)
                        infoCell(label: "Sell Fee", value: WealthFormat.money(holding.estimatedSellFee), tint: WealthTheme.orange)
                        infoCell(label: "Next Trade", value: holding.nextTradingText, tint: WealthTheme.gold)
                    }

                    HStack(spacing: 10) {
                        infoCell(label: "Last Refresh", value: holding.lastRefreshText, tint: WealthTheme.cyan)
                        infoCell(label: "Data Age", value: WealthFormat.age(holding.dataTimestamp), tint: WealthTheme.orange)
                    }
                }
            }
        }
        .padding(isDense ? 8 : 10)
        .background(listRowShell(cornerRadius: 18, accent: WealthTheme.gold))
        .padding(.horizontal, isDense ? 8 : 10)
    }
}
