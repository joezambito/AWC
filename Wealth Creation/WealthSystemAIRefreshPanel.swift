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

            Text("Locked cycle: IBKR soft at :09, :19, :39, :49. IBKR deep at :29 and :59. Soft AI at :10, :20, :40, :50. Heavy/Deep AI at :00 and :30. App open always triggers one immediate deep scan without shifting the fixed schedule.")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardShell(cornerRadius: 18))

            if hasDesktopSystemLayout {
                HStack(spacing: 10) {
                    wealthSystemSyncActionButton("RESYNC SCHEDULE") {
                        WealthEngineStore.shared.rescheduleTimers()
                    }
                    wealthSystemSyncActionButton("RUN SOFT") {
                        WealthEngineStore.shared.refresh(mode: .soft)
                    }
                    wealthSystemSyncActionButton("RUN HEAVY") {
                        WealthEngineStore.shared.refresh(mode: .heavy)
                    }
                }
            } else {
                Text("Phone safe mode keeps the locked cycle automatic. Use Mac only for manual scan triggers, not timer changes.")
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
