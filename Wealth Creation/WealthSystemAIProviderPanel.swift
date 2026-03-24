import SwiftUI

struct WealthSystemAIProviderPanel: View {
    @ObservedObject private var providerStore = WealthExternalDataStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DATA / TRAINING STACK")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("All provider, calendar, outcome, and retraining layers feeding the score.")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill(providerStore.readinessLabel, color: WealthTheme.green, darkText: true)
            }

            HStack(spacing: 8) {
                compactSummaryCard(title: "Live", value: "\(providerStore.activeProviderCount)", tint: WealthTheme.green)
                compactSummaryCard(title: "Options", value: providerStore.optionsFlowEnabled ? "ON" : "OFF", tint: WealthTheme.cyan)
                compactSummaryCard(title: "Dark Pool", value: providerStore.darkPoolEnabled ? "ON" : "OFF", tint: WealthTheme.purple)
                compactSummaryCard(title: "Outcome", value: providerStore.liveOutcomeLearningEnabled ? "ON" : "OFF", tint: WealthTheme.orange)
            }

            VStack(spacing: 8) {
                ForEach(providerStore.providerSources) { source in
                    HStack(spacing: 10) {
                        solidPill(source.status, color: source.tint, darkText: true)
                        Text(source.name.uppercased())
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text(source.detail.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    .padding(10)
                    .background(cardShell(cornerRadius: 16))
                }
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 22, tint: WealthTheme.green, secondaryTint: WealthTheme.cyan))
    }
}
