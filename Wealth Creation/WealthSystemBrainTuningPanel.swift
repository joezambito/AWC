import SwiftUI

struct WealthSystemBrainTuningPanel: View {
    @ObservedObject private var tuning = WealthBehaviorSettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("BRAIN TUNING")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                solidPill(tuning.isFactoryDefault ? "FACTORY" : "LIVE", color: tuning.isFactoryDefault ? WealthTheme.green : WealthTheme.cyan, darkText: true)
            }

            HStack(spacing: 10) {
                wealthSystemTuningStatCard(title: "CURRENT", value: tuning.isFactoryDefault ? "DEFAULTS" : "CUSTOM", tint: tuning.isFactoryDefault ? WealthTheme.green : WealthTheme.orange)
                wealthSystemTuningStatCard(title: "BUY GATE", value: "\(tuning.buyGate)", tint: WealthTheme.green)
                wealthSystemTuningStatCard(title: "FIT", value: String(format: "%.2f", tuning.targetFit), tint: WealthTheme.cyan)
            }

            HStack(spacing: 10) {
                wealthSystemTuningStatCard(title: "ROTATE", value: "\(tuning.rotateEdge)", tint: WealthTheme.orange)
                wealthSystemTuningStatCard(title: "FEE X", value: String(format: "%.1fx", tuning.feeEdgeMult), tint: WealthTheme.purple)
                wealthSystemTuningStatCard(title: "LOCK", value: "\(Int(tuning.profitLock))%", tint: WealthTheme.cyan)
            }

            wealthSystemTuningStepper(title: "BUY GATE", subtitle: "Higher = stricter entry quality", valueText: "\(tuning.buyGate)") {
                tuning.buyGate = max(1, tuning.buyGate - 1)
                WealthEngineStore.shared.refresh(mode: .heavy)
            } increment: {
                tuning.buyGate += 1
                WealthEngineStore.shared.refresh(mode: .heavy)
            }

            wealthSystemTuningStepper(title: "TARGET FIT", subtitle: "Minimum target alignment", valueText: String(format: "%.2f", tuning.targetFit)) {
                tuning.targetFit = max(0.01, tuning.targetFit - 0.01)
                WealthEngineStore.shared.refresh(mode: .heavy)
            } increment: {
                tuning.targetFit += 0.01
                WealthEngineStore.shared.refresh(mode: .heavy)
            }

            wealthSystemTuningStepper(title: "ROTATE EDGE", subtitle: "How much better a new setup must be", valueText: "\(tuning.rotateEdge)") {
                tuning.rotateEdge = max(1, tuning.rotateEdge - 1)
                WealthEngineStore.shared.refresh(mode: .heavy)
            } increment: {
                tuning.rotateEdge += 1
                WealthEngineStore.shared.refresh(mode: .heavy)
            }

            wealthSystemTuningStepper(title: "FEE EDGE X", subtitle: "Net edge required over costs", valueText: String(format: "%.1fx", tuning.feeEdgeMult)) {
                tuning.feeEdgeMult = max(1.0, tuning.feeEdgeMult - 0.1)
                WealthEngineStore.shared.refresh(mode: .heavy)
            } increment: {
                tuning.feeEdgeMult += 0.1
                WealthEngineStore.shared.refresh(mode: .heavy)
            }

            wealthSystemTuningStepper(title: "PROFIT LOCK", subtitle: "Default gain level to protect winners", valueText: "\(Int(tuning.profitLock))%") {
                tuning.profitLock = max(1, tuning.profitLock - 1)
                WealthEngineStore.shared.refresh(mode: .heavy)
            } increment: {
                tuning.profitLock += 1
                WealthEngineStore.shared.refresh(mode: .heavy)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("FACTORY DEFAULTS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                Text("Buy Gate \(WealthBehaviorSettingsStore.defaultBuyGate) · Target Fit \(String(format: "%.2f", WealthBehaviorSettingsStore.defaultTargetFit)) · Rotate Edge \(WealthBehaviorSettingsStore.defaultRotateEdge) · Fee Edge \(String(format: "%.1fx", WealthBehaviorSettingsStore.defaultFeeEdgeMult)) · Profit Lock \(Int(WealthBehaviorSettingsStore.defaultProfitLock))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)

                Button {
                    tuning.resetToFactoryDefaults()
                    WealthEngineStore.shared.refresh(mode: .heavy)
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("RESET BRAIN TUNING")
                    }
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(tuning.isFactoryDefault ? WealthTheme.grey.opacity(0.5) : WealthTheme.white)
                    )
                }
                .buttonStyle(.plain)
                .disabled(tuning.isFactoryDefault)
                .opacity(tuning.isFactoryDefault ? 0.72 : 1)
            }
        }
        .padding(14)
        .background(cardShell(cornerRadius: 24))
    }
}
