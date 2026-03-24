import SwiftUI

struct WealthSystemBrainOverviewPanel: View {
    let summary: String
    let modeLabel: String
    let modeTint: Color
    let pressure: String
    let driver: String
    let sizing: String
    let top: String
    let action: String
    let command: String
    let trust: String
    let rotate: String
    let trend: String
    let momentum: String
    let pattern: String
    let smart: String
    let event: String
    let anomaly: String
    let modelReadiness: String
    let computeMode: String
    let dataReadiness: String
    let runtimeCoverageText: String
    let learningSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BRAIN")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(summary)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill(modeLabel, color: modeTint, darkText: true)
            }

            HStack(spacing: 8) {
                compactSummaryCard(title: "Pressure", value: pressure, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Driver", value: driver, tint: WealthTheme.orange)
                compactSummaryCard(title: "Sizing", value: sizing, tint: WealthTheme.green)
            }

            HStack(spacing: 8) {
                compactSummaryCard(title: "Top", value: top, tint: WealthTheme.green)
                compactSummaryCard(title: "Action", value: action, tint: WealthTheme.orange)
                compactSummaryCard(title: "Command", value: command, tint: WealthTheme.green)
                compactSummaryCard(title: "Trust", value: trust, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Rotate", value: rotate, tint: WealthTheme.purple)
            }

            HStack(spacing: 8) {
                compactSummaryCard(title: "Trend", value: trend, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Momentum", value: momentum, tint: WealthTheme.orange)
                compactSummaryCard(title: "Pattern", value: pattern, tint: WealthTheme.purple)
            }

            HStack(spacing: 8) {
                compactSummaryCard(title: "Smart", value: smart, tint: WealthTheme.green)
                compactSummaryCard(title: "Event", value: event, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Anomaly", value: anomaly, tint: WealthTheme.red)
            }

            HStack(spacing: 8) {
                compactSummaryCard(title: "Model", value: modelReadiness, tint: WealthTheme.green)
                compactSummaryCard(title: "Compute", value: computeMode, tint: WealthTheme.orange)
                compactSummaryCard(title: "Data", value: dataReadiness, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Modules On", value: runtimeCoverageText, tint: WealthTheme.green)
            }

            Text(learningSummary)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(cardShell(cornerRadius: 18))
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 22, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
    }
}
