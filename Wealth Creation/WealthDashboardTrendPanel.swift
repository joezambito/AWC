import SwiftUI

struct WealthDashboardTrendPanel: View {
    let goalVector: WealthGoalVector
    let brainSnapshot: WealthBrainSnapshot
    let aiFlowPoints: [Double]
    let lastRefreshText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 12) {
                    iconBadge("chart.line.uptrend.xyaxis", tint: WealthTheme.cyan)
                        .frame(width: 54, height: 54)
                        .scaleEffect(0.78)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("LIVE TRENDS")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Target pressure and live brain direction")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                }

                Spacer()

                solidPill(brainSnapshot.hunger.rawValue, color: brainSnapshot.hunger.color, darkText: true)
            }

            HStack(spacing: 10) {
                WealthDashboardGoalCard(title: "Daily", progress: goalVector.daily, tint: WealthTheme.green)
                WealthDashboardGoalCard(title: "Compound", progress: goalVector.compound, tint: WealthTheme.cyan)
                WealthDashboardGoalCard(title: "Mission", progress: goalVector.mission, tint: WealthTheme.purple)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SIGNAL FLOW")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    Spacer()
                    Text("REFRESH \(lastRefreshText)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                WealthMiniGraph(points: aiFlowPoints, tint: WealthTheme.cyan)
                    .frame(height: 120)

                HStack(spacing: 10) {
                    miniReferenceCard(title: "Driver", value: brainSnapshot.targetDriver.uppercased(), accent: WealthTheme.orange, tag: "LIVE")
                    miniReferenceCard(title: "Pressure", value: brainSnapshot.targetPressure, accent: WealthTheme.cyan, tag: "TARGET")
                    miniReferenceCard(title: "Trust", value: brainSnapshot.trustSignal, accent: WealthTheme.green, tag: "DATA")
                }
            }
            .padding(12)
            .background(cardShell(cornerRadius: 22))
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
    }
}
