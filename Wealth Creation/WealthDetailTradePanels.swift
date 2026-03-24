import SwiftUI

extension OpportunityDetailView {
    private var localOpportunityAuditLabel: String {
#if targetEnvironment(macCatalyst)
        return "Trade Audit"
#else
        return "Decision Line"
#endif
    }

    var tradeIntelPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RESEARCH / TRADE MAP")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)

            intelRow(
                label: localOpportunityAuditLabel,
                value: "[\(opportunity.market)|Safety:\(opportunity.safety)/100|Fee:\(String(format: "%.3f", opportunity.roundTripFees / max(opportunity.trueCost, 1) * 100))%] AI entry \(opportunity.confidence)% confidence on \(opportunity.symbol) @ \(WealthFormat.money(opportunity.effectiveEntryPrice)). Buy total \(WealthFormat.money(opportunity.trueCost)). Buy fee \(WealthFormat.money(opportunity.brokerFee)). Sell fee \(WealthFormat.money(opportunity.sellFee)). Projected net profit \(WealthFormat.money(opportunity.expectedNetProfit))."
            )
            intelRow(label: "Recommended Shares", value: "\(opportunity.recommendedShares)")
            intelRow(label: "Live Price", value: WealthFormat.money(opportunity.price))
            intelRow(label: "Entry Price", value: WealthFormat.money(opportunity.effectiveEntryPrice))
            intelRow(label: "Order State", value: opportunity.orderState.rawValue)
            intelRow(label: "Order Price", value: WealthFormat.money(opportunity.submittedPrice))
            intelRow(label: "Live Move", value: wealthPercentMoveText(opportunity.liveMovePercent))
            intelRow(label: "Expected Move", value: wealthPercentMoveText(opportunity.projectedMovePercent))
            intelRow(label: "Entry Subtotal", value: WealthFormat.money(opportunity.entrySubtotalCost))
            intelRow(label: "Broker Fee", value: WealthFormat.money(opportunity.brokerFee))
            intelRow(label: "Sell Fee", value: WealthFormat.money(opportunity.sellFee))
            intelRow(label: "Buy Total", value: WealthFormat.money(opportunity.trueCost))
            intelRow(label: "Reserved Capital", value: WealthFormat.money(opportunity.reservedCapital))
            intelRow(label: "Net Exit Value", value: WealthFormat.money(opportunity.estimatedNetExitValue))
            intelRow(label: "Projected Net P/L", value: WealthFormat.money(opportunity.expectedNetProfit))
            intelRow(label: "Round Trip Fees", value: WealthFormat.money(opportunity.roundTripFees))
            intelRow(label: "Catalyst Bucket", value: opportunity.catalystBucket)
            intelRow(label: "Source Trigger", value: opportunity.sourceTrigger)
            intelRow(label: "Data Origin", value: opportunity.dataOrigin)
            intelRow(label: "Intel Drivers", value: opportunity.intelligenceDriverText)
            intelRow(label: "Intel Mesh", value: opportunity.intelligenceChannelText)
            intelRow(label: "Decision Matrix", value: opportunity.decisionMatrixText)
            intelRow(label: "Risk Matrix", value: opportunity.riskMatrixText)
            intelRow(label: "Options Flow", value: "\(Int(opportunity.optionsFlowStrength)) · \(opportunity.optionsFlowLabel)")
            intelRow(label: "Dark Pool", value: "\(Int(opportunity.darkPoolStrength)) · \(opportunity.darkPoolLabel)")
            intelRow(label: "Insider", value: "\(Int(opportunity.insiderStrength)) · \(opportunity.insiderLabel)")
            intelRow(label: "13F", value: "\(Int(opportunity.filingStrength)) · \(opportunity.filingLabel)")
            intelRow(label: "Earnings Risk", value: "\(Int(opportunity.earningsEventRisk)) · \(opportunity.earningsRiskLabel)")
            intelRow(label: "Macro Risk", value: "\(Int(opportunity.macroEventRisk)) · \(opportunity.macroRiskLabel)")
        }
        .padding(18)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.purple, secondaryTint: WealthTheme.orange))
    }

    func intelRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(WealthTheme.cyan)
                .frame(width: 150, alignment: .leading)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
