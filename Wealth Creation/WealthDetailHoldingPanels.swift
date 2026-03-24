import SwiftUI

extension HoldingDetailView {
    var technicalPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TECHNICAL / FUNDAMENTAL")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            intelRow(label: "AI Rank", value: "\(holding.aiBand)/10")
            intelRow(label: "Confidence", value: "\(holding.confidence)%")
            intelRow(label: "Current Price", value: WealthFormat.money(holding.effectiveCurrentPrice))
            intelRow(label: "Buy Price", value: WealthFormat.money(holding.averagePrice))
            intelRow(label: "Cost Basis", value: WealthFormat.money(holding.costBasis))
            intelRow(label: "Net P/L", value: wealthPnLText(holding.netPnL))
            intelRow(label: "Live Move", value: wealthPercentMoveText(holding.liveMovePercent))
            intelRow(label: "Net Return", value: wealthPercentMoveText(holding.netReturnPercent))
            if holding.orderIntent == .sellPending {
                intelRow(label: "Pending Shares", value: "\(holding.pendingShares)")
                intelRow(label: "Pending Age", value: holding.pendingAgeText ?? "Just sent")
                intelRow(label: "Pending Net P/L", value: wealthPnLText(holding.pendingNetPnL))
                intelRow(label: "Pending Net Return", value: wealthPercentMoveText(holding.pendingNetReturnPercent))
            }
        }
        .padding(18)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
    }

    var feesPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FEES / SELL NOW")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            intelRow(label: "Gross Value", value: WealthFormat.money(holding.marketValue))
            intelRow(label: "Broker Fee In", value: WealthFormat.money(holding.buyFee))
            intelRow(label: "Broker Fee Out", value: WealthFormat.money(holding.estimatedSellFee))
            intelRow(label: "Net Sell Value", value: WealthFormat.money(holding.netLiquidationValue))
            intelRow(label: "Net P/L", value: wealthPnLText(holding.netPnL))
            if holding.orderIntent == .sellPending {
                intelRow(label: "Pending Gross", value: WealthFormat.money(holding.pendingGrossValue))
                intelRow(label: "Pending Sell Fee", value: WealthFormat.money(holding.pendingSellFee))
                intelRow(label: "Pending Basis", value: WealthFormat.money(holding.pendingCostBasis))
                intelRow(label: "Pending Net", value: WealthFormat.money(holding.pendingNetValue))
                intelRow(label: "Pending Net P/L", value: wealthPnLText(holding.pendingNetPnL))
                intelRow(label: "Capital Status", value: "Not added to Capital until broker confirms")
            }
        }
        .padding(18)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.orange, secondaryTint: WealthTheme.red))
    }

    func intelRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
                .frame(width: 160, alignment: .leading)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
