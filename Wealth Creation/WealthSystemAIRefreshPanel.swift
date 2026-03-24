import SwiftUI

struct WealthSystemAIRefreshPanel: View {
    let hasDesktopSystemLayout: Bool
    @Binding var lightRefreshMinutes: Double
    @Binding var heavyRefreshMinutes: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ENGINE REFRESH")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Manual engine controls stay on Mac. Phone keeps the cycle automatic so the app stays smooth.")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill(hasDesktopSystemLayout ? "FULL" : "AUTO", color: hasDesktopSystemLayout ? WealthTheme.orange : WealthTheme.cyan, darkText: true)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SOFT REFRESH")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    wealthSystemMinutesField(value: $lightRefreshMinutes, tint: WealthTheme.cyan)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("HEAVY REFRESH")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    wealthSystemMinutesField(value: $heavyRefreshMinutes, tint: WealthTheme.orange)
                }
            }

            if hasDesktopSystemLayout {
                HStack(spacing: 10) {
                    wealthSystemSyncActionButton("APPLY TIMERS") {
                        WealthEngineStore.shared.rescheduleTimers()
                        WealthEngineStore.shared.refresh(mode: .heavy)
                    }
                    wealthSystemSyncActionButton("RUN SOFT") {
                        WealthEngineStore.shared.refresh(mode: .soft)
                    }
                    wealthSystemSyncActionButton("RUN HEAVY") {
                        WealthEngineStore.shared.refresh(mode: .heavy)
                    }
                }
            } else {
                Text("Phone safe mode keeps refresh actions automatic. Use Mac for manual engine controls.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(cardShell(cornerRadius: 18))
            }
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 26, tint: WealthTheme.cyan, secondaryTint: WealthTheme.blue))
    }
}
