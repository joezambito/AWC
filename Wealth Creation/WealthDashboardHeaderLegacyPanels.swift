import SwiftUI

struct WealthLegacyHeaderCardView: View {
    let hasDesktopLayout: Bool
    let lastRefreshText: String
    let aiActivationLabel: String
    let aiActivationTint: Color
    let availableCapitalText: String
    let accountValueText: String
    let floorReserveText: String
    let buyReservedText: String
    let sellReturningText: String
    let totalPnLText: String
    let totalPnLTint: Color

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DASHBOARD")
                        .font(.system(size: hasDesktopLayout ? 20 : 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Last refresh \(lastRefreshText)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()

                solidPill(aiActivationLabel, color: aiActivationTint, darkText: true)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Capital", value: availableCapitalText, tint: .white)
                compactSummaryCard(title: "Account Value", value: accountValueText, tint: WealthTheme.cyan)
                compactSummaryCard(title: "P / L", value: totalPnLText, tint: totalPnLTint)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Floor Reserve", value: floorReserveText, tint: WealthTheme.orange)
                compactSummaryCard(title: "Buy Reserve", value: buyReservedText, tint: WealthTheme.blue)
                compactSummaryCard(title: "Sell Returning", value: sellReturningText, tint: WealthTheme.purple)
            }
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
    }
}
