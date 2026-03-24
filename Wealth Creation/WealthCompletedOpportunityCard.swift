import SwiftUI

struct CompletedOpportunityCard: View {
    let opportunity: Opportunity
    var isExpanded: Bool = false
    var usesDenseCollapsedState: Bool = false
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    private var isSellCompletion: Bool {
        opportunity.commandText == "SELL COMPLETED" || opportunity.decisionBias == .avoid
    }

    private var completionLabel: String {
        isSellCompletion ? "SELL FILLED" : "BUY FILLED"
    }

    var body: some View {
        let isDense = usesDenseCollapsedState && !isExpanded

        return VStack(spacing: isDense ? 6 : 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(opportunity.symbol)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: true, vertical: false)

                    Text("\(completionLabel) @ \(WealthFormat.money(opportunity.submittedPrice))")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.74))

                    Text("Hold View \(opportunity.predictedHoldText)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.purple)

                    Text(wealthPnLText(opportunity.expectedNetProfit, prefixPositive: "Net "))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(wealthPnLTint(opportunity.expectedNetProfit))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    cardStatusIcons
                    solidPill(completionLabel, color: Color.white.opacity(0.85), darkText: true)
                    Text(opportunity.lastRefreshText)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
            }

            HStack(spacing: 10) {
                infoCell(label: "Entry Price", value: WealthFormat.money(opportunity.submittedPrice), tint: .white)
                infoCell(label: "Capital", value: WealthFormat.money(opportunity.trueCost), tint: .white)
                infoCell(label: "Live Price", value: WealthFormat.money(opportunity.price), tint: wealthPercentMoveTint(opportunity.priceChangePercent))
                infoCell(label: isSellCompletion ? "Cash Returned" : "Net Exit", value: WealthFormat.money(opportunity.estimatedNetExitValue), tint: wealthNetExitTint(netExit: opportunity.estimatedNetExitValue, buyTotal: opportunity.trueCost))
            }

            HStack(spacing: 10) {
                infoCell(label: "Net P/L", value: wealthPnLText(opportunity.expectedNetProfit), tint: wealthPnLTint(opportunity.expectedNetProfit))
                percentMoveInfoCell(opportunity.priceChangePercent)
                infoCell(label: "Fee In", value: WealthFormat.money(opportunity.brokerFee), tint: WealthTheme.orange)
                infoCell(label: "Hold View", value: opportunity.predictedHoldText, tint: WealthTheme.purple)
            }

            infoCell(label: "Decision Line", value: opportunity.aiCommentary, tint: .white)

            HStack(spacing: 10) {
                infoCell(label: "Last Refresh", value: opportunity.lastRefreshText, tint: WealthTheme.cyan)
                infoCell(label: "Data Age", value: opportunity.sourceAgeText, tint: WealthTheme.orange)
                infoCell(label: "Next Trade", value: opportunity.nextTradingText, tint: WealthTheme.gold)
            }

            if isExpanded {
                HStack(spacing: 10) {
                    infoCell(label: "Fee Out", value: WealthFormat.money(opportunity.sellFee), tint: WealthTheme.orange)
                    infoCell(label: "Order", value: completionLabel, tint: Color.white.opacity(0.88))
                }
                infoCell(label: "Post-Trade Review", value: opportunity.readinessSummary, tint: opportunity.cardSignalTint)
                infoCell(label: "Score Trail", value: opportunity.scoreDriftText, tint: opportunity.scoreTint)
                infoCell(label: "Conf Trail", value: opportunity.confidenceDriftText, tint: opportunity.confidenceTint)
                infoCell(label: "Decision Matrix", value: opportunity.decisionMatrixText, tint: WealthTheme.cyan)
                infoCell(label: "Risk Matrix", value: opportunity.riskMatrixText, tint: WealthTheme.orange)
                infoCell(label: "Trust", value: opportunity.trustReason, tint: opportunity.trustState.color)
                infoCell(label: "Research Stack", value: opportunity.researchStackText, tint: .white)
                if !opportunity.warningReason.isEmpty {
                    infoCell(label: "Warning", value: opportunity.warningReason, tint: WealthTheme.gold)
                }
                infoCell(label: "Research", value: opportunity.sourceSummary, tint: .white)
            }
        }
        .padding(isDense ? 8 : 10)
        .background(
            listRowShell(cornerRadius: 18, accent: Color.white.opacity(0.92))
        )
        .padding(.horizontal, isDense ? 8 : 10)
    }

    @ViewBuilder
    private var cardStatusIcons: some View {
        HStack(spacing: 6) {
            if opportunity.ruleShieldVisible {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(WealthTheme.orange)
            }
            if protection.surgeEnabled {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(WealthTheme.gold)
            }
        }
    }
}
