import SwiftUI

struct WealthSystemStatusRailView: View {
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared
    @ObservedObject private var brokerStore = WealthBrokerStore.shared
    @ObservedObject private var syncStore = WealthSyncStore.shared
    @ObservedObject private var engine = WealthEngineStore.shared
    @ObservedObject private var brainStore = WealthBrainStore.shared

    @AppStorage("awc_scan_refresh_light_minutes") private var lightRefreshMinutes: Double = 10
    @AppStorage("awc_scan_refresh_heavy_minutes") private var heavyRefreshMinutes: Double = 30

    var body: some View {
        VStack(spacing: 12) {
            wealthSystemHeroPanel(title: "SYSTEM LIVE", subtitle: "Mac-facing status rail", icon: "desktopcomputer", badge: syncStore.syncStatus, badgeColor: WealthTheme.green)
            wealthSystemTuningStatCard(title: "BROKER", value: brokerStore.selectedBroker.name, tint: WealthTheme.cyan)
            wealthSystemTuningStatCard(title: "MODE", value: brokerStore.liveTradingEnabled ? "LIVE" : "PAPER", tint: brokerStore.liveTradingEnabled ? WealthTheme.orange : WealthTheme.cyan)
            wealthSystemTuningStatCard(title: "FLOOR", value: WealthFormat.money(protection.floorReserve), tint: WealthTheme.purple)
            wealthSystemTuningStatCard(title: "SOFT", value: "\(Int(lightRefreshMinutes))m", tint: WealthTheme.cyan)
            wealthSystemTuningStatCard(title: "HEAVY", value: "\(Int(heavyRefreshMinutes))m", tint: WealthTheme.orange)
            wealthSystemTuningStatCard(title: "HOST", value: syncStore.brokerHost, tint: WealthTheme.cyan)
            wealthSystemTuningStatCard(title: "PORT", value: "\(syncStore.brokerPort)", tint: WealthTheme.orange)
            wealthSystemTuningStatCard(title: "ENGINE", value: engine.brainSnapshot.mode.rawValue, tint: engine.brainSnapshot.mode.color)
            wealthSystemTuningStatCard(title: "REGIME", value: engine.brainSnapshot.regime.rawValue, tint: engine.brainSnapshot.regime.color)
            wealthSystemTuningStatCard(title: "MODEL", value: engine.brainSnapshot.modelReadiness, tint: WealthTheme.green)
            wealthSystemTuningStatCard(title: "DATA", value: engine.brainSnapshot.dataReadiness, tint: WealthTheme.cyan)
            wealthSystemTuningStatCard(title: "GOVERN", value: brainStore.modelState.governanceState, tint: WealthTheme.purple)
            wealthSystemTuningStatCard(title: "TRAIN", value: brainStore.modelState.trainingState, tint: WealthTheme.orange)

            if let latest = syncStore.syncLog.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LAST SYNC EVENT")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                    Text(latest.title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.green)
                    Text(latest.detail)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(sectionGlowShell(cornerRadius: 20, tint: WealthTheme.green))
            }

            auditTrailPanel
        }
    }

    private var auditTrailPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AUDIT TRAIL")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Track broker events, decision changes, and capital history for later review.")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill("MAC", color: WealthTheme.orange, darkText: true)
            }

            if syncStore.syncLog.isEmpty {
                Text("Audit history will appear here once broker sync and trade events are recorded.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(cardShell(cornerRadius: 18))
            } else {
                ForEach(Array(syncStore.syncLog.prefix(4))) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.title)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                            Text(WealthFormat.ageText(item.timestamp))
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(WealthTheme.grey)
                        }

                        Text(item.detail)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(cardShell(cornerRadius: 18))
                }
            }
        }
        .padding(12)
        .background(sectionGlowShell(cornerRadius: 20, tint: WealthTheme.purple))
    }
}
