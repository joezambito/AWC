import SwiftUI

extension OpportunityDetailView {
    var detailHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(opportunity.symbol)
                        .font(.system(size: 33, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(opportunity.market)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    Text(opportunity.sector)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.purple.opacity(0.88))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    solidPill("SCORE \(opportunity.aiScore)", color: opportunity.scoreStyle.color, darkText: true)
                    solidPill("CONF \(opportunity.confidence)%", color: wealthConfidenceTint(opportunity.confidence), darkText: true)
                }
            }

            HStack(spacing: 10) {
                infoCell(label: "Safety", value: "\(opportunity.safety)", tint: WealthTheme.green)
                infoCell(label: "Risk", value: opportunity.aiRiskStance, tint: opportunityDetailRiskTint(opportunity.aiRiskStance))
                infoCell(label: "Rank", value: "#\(opportunity.aiBandLabel)", tint: WealthTheme.cyan)
            }

            HStack(spacing: 10) {
                infoCell(label: "Decision", value: opportunity.decisionBias.rawValue, tint: opportunity.decisionBias.color)
                infoCell(label: "Permit", value: opportunity.permission.rawValue, tint: opportunity.permission.color)
                infoCell(label: "Order", value: detailOrderText, tint: detailOrderTint)
                infoCell(label: "Command", value: opportunity.commandText, tint: WealthTheme.green)
                infoCell(label: "Trust", value: opportunity.trustState.rawValue, tint: opportunity.trustState.color)
            }
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 28, tint: opportunity.scoreStyle.color, secondaryTint: WealthTheme.cyan))
    }

    var timingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BRAIN TIMING")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.96))
            HStack(spacing: 10) {
                infoCell(label: "Decision Age", value: opportunity.analysisAgeText, tint: WealthTheme.green)
                infoCell(label: "Data Age", value: opportunity.sourceAgeText, tint: WealthTheme.red)
                infoCell(label: "Brain Mode", value: opportunity.aggressionMode.rawValue, tint: opportunity.aggressionMode.color)
                infoCell(label: "Regime", value: opportunity.marketRegime.rawValue, tint: opportunity.marketRegime.color)
            }
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
    }

    var researchPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RESEARCH SUMMARY")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.96))
            Text(opportunity.sourceSummary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.90))
            HStack(spacing: 10) {
                infoCell(label: "Prospect", value: opportunity.prospect, tint: WealthTheme.green)
                infoCell(label: "Size Rule", value: "\(opportunity.allocationPercent)%", tint: WealthTheme.orange)
                infoCell(label: "Conviction", value: opportunity.conviction.rawValue, tint: opportunity.conviction.color)
                infoCell(label: "Rotate", value: opportunity.rotationBias.rawValue, tint: opportunity.rotationBias.color)
                infoCell(label: "Style", value: opportunity.executionStyle.rawValue, tint: opportunity.executionStyle.color)
            }
            HStack(spacing: 10) {
                infoCell(label: "Target", value: opportunity.targetDirective, tint: WealthTheme.green)
                infoCell(label: "Coverage", value: "\(opportunity.targetCoveragePercent)%", tint: WealthTheme.cyan)
                infoCell(label: "Hunger", value: opportunity.hungerMode.rawValue, tint: opportunity.hungerMode.color)
                infoCell(label: "Source Trust", value: "\(opportunity.sourceReliabilityScore)", tint: opportunity.trustState.color)
                infoCell(label: "Share Trust", value: "\(opportunity.shareReliabilityScore)", tint: opportunity.trustState.color)
            }
            HStack(spacing: 10) {
                infoCell(label: "Options", value: opportunity.optionsFlowLabel, tint: WealthTheme.cyan)
                infoCell(label: "Dark Pool", value: opportunity.darkPoolLabel, tint: WealthTheme.purple)
                infoCell(label: "Insider", value: opportunity.insiderLabel, tint: WealthTheme.orange)
                infoCell(label: "13F", value: opportunity.filingLabel, tint: WealthTheme.green)
            }
            HStack(spacing: 10) {
                infoCell(label: "Earnings", value: opportunity.earningsRiskLabel, tint: opportunity.earningsEventRisk >= 40 ? WealthTheme.orange : WealthTheme.green)
                infoCell(label: "Macro", value: opportunity.macroRiskLabel, tint: opportunity.macroEventRisk >= 40 ? WealthTheme.orange : WealthTheme.cyan)
            }
            Text(opportunity.buyReason).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.92))
            Text(opportunity.decisionMatrixText).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(WealthTheme.cyan)
            Text(opportunity.riskMatrixText).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(WealthTheme.orange)
            Text(opportunity.trustReason).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(opportunity.trustState.color)
            Text(opportunity.commandText).font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(WealthTheme.green)
            Text(opportunity.rotationReason).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(WealthTheme.orange)
            if !opportunity.warningReason.isEmpty {
                Text(opportunity.warningReason)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }
            if !opportunity.intelligenceDrivers.isEmpty {
                HStack(spacing: 10) {
                    infoCell(label: "Intel Drivers", value: opportunity.intelligenceDriverText, tint: WealthTheme.purple)
                    infoCell(label: "Intel Mesh", value: opportunity.intelligenceChannelText, tint: WealthTheme.orange)
                }
            }
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.green, secondaryTint: WealthTheme.cyan))
    }

    private var detailOrderText: String {
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
            return opportunity.sessionState.canTradeNow ? "ORDER SENT" : "ORDER STAGED"
        }
    }

    private var detailOrderTint: Color {
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

private func opportunityDetailRiskTint(_ label: String) -> Color {
    switch label {
    case "AGGRESSIVE":
        return WealthTheme.orange
    case "ACTIVE":
        return WealthTheme.cyan
    case "DEFENSIVE":
        return WealthTheme.red
    default:
        return WealthTheme.green
    }
}
