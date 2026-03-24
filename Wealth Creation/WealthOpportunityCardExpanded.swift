import SwiftUI

struct OpportunityCardExpandedDetailsView: View {
    let opportunity: Opportunity
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("STATUS")
            detailRow("READINESS", opportunity.readinessSummary, tint: opportunity.cardSignalTint)
            detailRow("ORDER", orderStageText, tint: orderStageTint)
            detailRow("SESSION", opportunity.sessionState.rawValue, tint: opportunity.sessionState.color)
            detailRow("TARGET", opportunity.targetDirective, tint: WealthTheme.green)
            detailRow("TRADE", opportunity.tradeabilityLabel, tint: opportunity.tradeabilityTint)
            detailRow("AI SCORE", "\(opportunity.aiScore)", tint: opportunity.scoreTint)
            detailRow("CONFIDENCE", "\(opportunity.confidence)%", tint: opportunity.confidenceTint)
            detailRow("RANK", "#\(opportunity.rank)", tint: WealthTheme.cyan)

            sectionTitle("MONEY")
            detailRow("SHARES", "\(opportunity.recommendedShares)", tint: WealthTheme.cyan)
            detailRow("BUY PRICE", WealthFormat.money(opportunity.submittedPrice), tint: .white)
            detailRow("LIVE PRICE", WealthFormat.money(opportunity.price), tint: priceTint)
            detailRow("MOVE %", wealthPercentMoveText(opportunity.liveMovePercent), tint: wealthPercentMoveTint(opportunity.liveMovePercent))
            detailRow("P / L", wealthPnLText(opportunity.liveNetProfit), tint: wealthPnLTint(opportunity.liveNetProfit))
            detailRow("BUY FEE", WealthFormat.money(opportunity.brokerFee), tint: WealthTheme.orange)
            detailRow("SELL FEE", WealthFormat.money(opportunity.liveSellFee), tint: WealthTheme.orange)
            detailRow("CURR TOTAL", WealthFormat.money(opportunity.liveNetExitValue), tint: wealthNetExitTint(netExit: opportunity.liveNetExitValue, buyTotal: opportunity.trueCost))
            detailRow("BUFFER SELL", opportunity.fixedBufferExitSummary, tint: WealthTheme.orange)
            detailRow("SHIELD SELL", opportunity.shieldExitSummary, tint: WealthTheme.red)

            sectionTitle("AI FINDINGS")
            noteBlock("WHAT AI FOUND", opportunity.aiFoundHeadline, tint: WealthTheme.cyan)
            noteBlock("AI DETAIL", opportunity.aiFoundDetail, tint: .white.opacity(0.94))
            noteBlock("BLOCKERS", opportunity.blockerSummary, tint: WealthTheme.orange)
            noteBlock("WHAT NEXT", opportunity.scoreUpgradePath, tint: WealthTheme.purple)
            noteBlock("DECISION LINE", opportunity.buyReason, tint: .white.opacity(0.92))

            sectionTitle("SIGNALS")
            detailRow("OPTIONS", opportunity.optionsFlowLabel, tint: WealthTheme.cyan)
            detailRow("DARK POOL", opportunity.darkPoolLabel, tint: WealthTheme.purple)
            detailRow("INSIDER", opportunity.insiderLabel, tint: WealthTheme.orange)
            detailRow("13F", opportunity.filingLabel, tint: WealthTheme.green)
            detailRow("EARNINGS", opportunity.earningsRiskLabel, tint: opportunity.earningsEventRisk >= 40 ? WealthTheme.orange : WealthTheme.green)
            detailRow("MACRO", opportunity.macroRiskLabel, tint: opportunity.macroEventRisk >= 40 ? WealthTheme.orange : WealthTheme.cyan)

            sectionTitle("TIMING")
            detailRow("WINDOW", opportunity.timeWindow, tint: WealthTheme.purple)
            detailRow("LAST REFRESH", opportunity.lastRefreshText, tint: WealthTheme.cyan)
            detailRow("DATA AGE", opportunity.sourceAgeText, tint: WealthTheme.orange)
            detailRow("NEXT TRADE", opportunity.nextTradingText, tint: WealthTheme.gold)
            detailRow("SOURCE", opportunity.sourceTrigger, tint: WealthTheme.cyan)

            sectionTitle("DETAIL")
            textBlock(opportunity.aiCommentary, tint: .white.opacity(0.92))
            textBlock("SCORE TRAIL · \(opportunity.scoreDriftText)", tint: opportunity.scoreTint)
            textBlock("CONF TRAIL · \(opportunity.confidenceDriftText)", tint: opportunity.confidenceTint)
            textBlock(opportunity.researchStackText, tint: .white.opacity(0.88))
            textBlock("DECISION MATRIX · \(opportunity.decisionMatrixText)", tint: WealthTheme.cyan)
            textBlock("RISK MATRIX · \(opportunity.riskMatrixText)", tint: WealthTheme.orange)
            textBlock(opportunity.commandText, tint: WealthTheme.green)
            textBlock(opportunity.trustReason, tint: opportunity.trustState.color)
            if !opportunity.warningReason.isEmpty {
                textBlock(opportunity.warningReason, tint: WealthTheme.gold)
            }
        }
    }

    private var orderStageText: String {
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

    private var orderStageTint: Color {
        switch opportunity.orderState {
        case .filled:
            return WealthTheme.white
        case .ready:
            return opportunity.sessionState.canTradeNow ? WealthTheme.green : WealthTheme.gold
        default:
            return orderStateTint(opportunity.orderState)
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func detailRow(_ label: String, _ value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(tint.opacity(0.88))
                .frame(width: 98, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(cardCellBackground(tint: tint))
    }

    private func textBlock(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(cardCellBackground(tint: tint))
    }

    private func noteBlock(_ title: String, _ text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(WealthTheme.green)
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(cardCellBackground(tint: WealthTheme.green))
    }

    private func cardCellBackground(tint: Color) -> some View {
        cardShell(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }
}
