import SwiftUI

struct HoldingDetailView: View {
    let holding: Holding
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            WealthTheme.background
                .ignoresSafeArea()

            GeometryReader { proxy in
                let isWide = proxy.size.width >= 980

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        hero

                        if isWide {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(spacing: 10) {
                                    researchSummary
                                    technicalPanel
                                }
                                .frame(maxWidth: .infinity, alignment: .top)

                                feesPanel
                                    .frame(maxWidth: .infinity, alignment: .top)
                            }
                        } else {
                            researchSummary
                            technicalPanel
                            feesPanel
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 104)
                    .padding(.bottom, 28)
                    .frame(maxWidth: isWide ? 1180 : .infinity)
                    .frame(maxWidth: .infinity)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 66, height: 66)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
            .padding(.top, 48)
        }
    }

    var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.symbol)
                        .font(.system(size: 33, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(holding.market)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    solidPill("SCORE \(holding.aiScore)", color: holding.scoreStyle.color, darkText: true)
                    solidPill("CONF \(holding.confidence)%", color: wealthHoldingConfidenceTint(holding.confidence), darkText: true)
                }
            }

            HStack(spacing: 10) {
                infoCell(label: "Signal Age", value: WealthFormat.age(holding.analysisTimestamp), tint: WealthTheme.green)
                infoCell(label: "Data Age", value: WealthFormat.age(holding.dataTimestamp), tint: WealthTheme.orange)
                infoCell(label: holding.orderIntent == .live ? "Risk" : "Order", value: holding.orderIntent == .live ? holding.riskLabel : holding.orderState.rawValue, tint: holding.orderIntent == .live ? localDetailRiskTint(holding.riskLabel) : holding.orderState.color)
            }

            HStack(spacing: 10) {
                infoCell(label: "Max Loss", value: holding.manualShieldLabel, tint: WealthTheme.orange)
                infoCell(label: "Capital Shield", value: holding.shieldExitSummary, tint: WealthTheme.red)
                infoCell(label: "Surge Protector", value: holding.surgeStatusLabel, tint: WealthProtectionSettingsStore.shared.surgeEnabled ? WealthTheme.gold : WealthTheme.grey)
                infoCell(label: "Profit Lock", value: holding.surgeExitSummary, tint: WealthTheme.gold)
            }

            HStack(spacing: 10) {
                infoCell(label: holding.orderIntent == .sellPending ? "Live Shares" : "Shares", value: "\(holding.orderIntent == .sellPending ? holding.availableShares : holding.shares)", tint: .white)
                infoCell(label: holding.orderIntent == .sellPending ? "Pending" : "Buy Price", value: holding.orderIntent == .sellPending ? "\(holding.pendingShares)" : WealthFormat.money(holding.averagePrice), tint: holding.orderIntent == .sellPending ? WealthTheme.purple : .white)
                infoCell(label: holding.orderIntent == .sellPending ? "Exit" : "Current", value: holding.orderIntent == .sellPending ? WealthFormat.money(holding.pendingExitPrice) : WealthFormat.money(holding.effectiveCurrentPrice), tint: holding.orderIntent == .sellPending ? holding.orderState.color : wealthPercentMoveTint(holding.liveMovePercent))
                infoCell(label: "P/L", value: wealthPnLText(holding.orderIntent == .sellPending ? holding.pendingNetPnL : holding.netPnL), tint: wealthPnLTint(holding.orderIntent == .sellPending ? holding.pendingNetPnL : holding.netPnL))
                infoCell(label: "Buy Total", value: WealthFormat.money(holding.buyTotalCost), tint: .white)
            }
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 28, tint: holding.scoreStyle.color, secondaryTint: WealthTheme.cyan))
    }

    var researchSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RESEARCH SUMMARY")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.96))
            Text(holding.reviewSummary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.90))
            HStack(spacing: 10) {
                infoCell(label: "Prospect", value: holding.prospect, tint: WealthTheme.green)
                infoCell(label: "Window", value: holding.timeWindow, tint: WealthTheme.gold)
                infoCell(label: "Signal", value: holding.dataOrigin, tint: WealthTheme.purple)
            }
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.green, secondaryTint: WealthTheme.cyan))
    }

    func localDetailRiskTint(_ label: String) -> Color {
        switch label.uppercased() {
        case "AGGRESSIVE": return WealthTheme.orange
        case "ACTIVE": return WealthTheme.cyan
        case "DEFENSIVE": return WealthTheme.red
        default: return WealthTheme.green
        }
    }
}
