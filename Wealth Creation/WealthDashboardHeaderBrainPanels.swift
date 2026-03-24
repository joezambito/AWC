import SwiftUI

struct WealthBrainSummaryPanel: View {
    let snapshot: WealthBrainSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BRAIN")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(snapshot.summary)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill(snapshot.mode.rawValue, color: snapshot.mode.color, darkText: true)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Pressure", value: snapshot.targetPressure, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Driver", value: snapshot.targetDriver.uppercased(), tint: WealthTheme.orange)
                compactSummaryCard(title: "Sizing", value: snapshot.capitalDiscipline, tint: WealthTheme.green)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Model", value: snapshot.modelReadiness, tint: WealthTheme.green)
                compactSummaryCard(title: "Data", value: snapshot.dataReadiness, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Regime", value: snapshot.regime.rawValue, tint: snapshot.regime.color)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Top", value: snapshot.hottestSymbol, tint: WealthTheme.green)
                compactSummaryCard(title: "Action", value: snapshot.hottestDecision, tint: WealthTheme.orange)
                compactSummaryCard(title: "Command", value: snapshot.hottestCommand, tint: WealthTheme.green)
                compactSummaryCard(title: "Trust", value: snapshot.trustSignal, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Rotate", value: snapshot.rotationSignal, tint: WealthTheme.purple)
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 20, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
    }
}
