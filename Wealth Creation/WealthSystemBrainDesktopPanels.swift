import SwiftUI

struct WealthSystemDesktopBrainPanel: View {
    let modelState: WealthBrainModelState
    let learningSummary: String
    let featureSnapshots: [WealthBrainFeatureSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DESKTOP BRAIN STACK")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Mac carries the heavier model memory, richer compute state, and deeper operator view while the phone stays faster and lighter.")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill(modelState.computeMode, color: WealthTheme.orange, darkText: true)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Model", value: modelState.modelVersion, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Ready", value: modelState.readiness, tint: WealthTheme.green)
                compactSummaryCard(title: "Training", value: modelState.trainingState, tint: WealthTheme.purple)
                compactSummaryCard(title: "Govern", value: modelState.governanceState, tint: WealthTheme.orange)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Top", value: modelState.topSymbol, tint: WealthTheme.green)
                compactSummaryCard(title: "Features", value: "\(modelState.featureSnapshots)", tint: WealthTheme.cyan)
                compactSummaryCard(title: "Anomaly", value: modelState.anomalyWatch, tint: WealthTheme.red)
                compactSummaryCard(title: "Data", value: modelState.dataReadiness, tint: WealthTheme.blue)
            }

            Text(learningSummary)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.76))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardShell(cornerRadius: 18))

            if !featureSnapshots.isEmpty {
                VStack(spacing: 8) {
                    ForEach(featureSnapshots) { snapshot in
                        HStack(spacing: 10) {
                            compactSummaryCard(title: snapshot.symbol, value: "#\(snapshot.rank)", tint: WealthTheme.green)
                            compactSummaryCard(title: "Trend", value: snapshot.trend, tint: WealthTheme.cyan)
                            compactSummaryCard(title: "Pattern", value: snapshot.pattern, tint: WealthTheme.blue)
                            compactSummaryCard(title: "Money", value: snapshot.smartMoney, tint: WealthTheme.orange)
                            compactSummaryCard(title: "Event", value: snapshot.event, tint: WealthTheme.cyan)
                            compactSummaryCard(title: "Exec", value: snapshot.execution, tint: WealthTheme.purple)
                            compactSummaryCard(title: "Risk", value: snapshot.anomaly, tint: WealthTheme.red)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.orange, secondaryTint: WealthTheme.purple))
    }
}
