import SwiftUI

struct WealthSystemAIStatusPanel: View {
    private struct StartupStatusRow: Identifiable {
        let id: String
        let title: String
        let status: String
        let detail: String
        let timeText: String
        let tint: Color
    }

    let activationCycleComplete: Bool
    let activationStage: Int
    let activationStageTotal: Int
    let lightRefreshMinutes: Int
    let heavyRefreshMinutes: Int

    @ObservedObject private var protection = WealthProtectionSettingsStore.shared
    @ObservedObject private var engine = WealthEngineStore.shared
    @ObservedObject private var universeStore = WealthMarketUniverseStore.shared
    @ObservedObject private var marketCycleStore = WealthMarketViewCycleStore.shared
    @ObservedObject private var syncStore = WealthSyncStore.shared
    @ObservedObject private var liveMarketStore = WealthLiveMarketDataStore.shared
    @ObservedObject private var providerStore = WealthExternalDataStore.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var summaryColumns: [GridItem] {
        let minimum = usesCompactLayout ? 120.0 : 140.0
        return [GridItem(.adaptive(minimum: minimum), spacing: 10, alignment: .top)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI STATUS")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    WealthEngineStore.shared.forceRefreshNow()
                } label: {
                    Text("FORCE REFRESH")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(activationCycleComplete ? WealthTheme.green : WealthTheme.cyan)
                        )
                }
                .buttonStyle(.plain)
                solidPill(
                    activationCycleComplete ? "READY" : (engine.startupSequenceInFlight ? "SERIAL" : "STAGED"),
                    color: activationCycleComplete ? WealthTheme.green : WealthTheme.cyan,
                    darkText: true
                )
            }

            LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 10) {
                cycleSummaryCard
                compactSummaryCard(title: "IBKR", value: "9/19/29", tint: WealthTheme.cyan)
                compactSummaryCard(title: "AI", value: "10/20/30", tint: WealthTheme.orange)
            }

            startupDownloadTable

            Text("Phone startup is serialized: app open, 2s hold, universe refresh, AI scan, pending publish, then market warmup. Only one stage runs at a time, and the dashboard waits for the current stage to finish before the next one starts.")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardShell(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 8) {
                Text("BRAIN ALERTS")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                wealthSystemToggleCard(
                    title: "SPEED ALERT",
                    subtitle: "Sends a notification to your phone when price momentum is moving unusually fast and Surge Protector is watching the move.",
                    tint: WealthTheme.cyan,
                    isOn: $protection.speedAlertEnabled
                )

                wealthSystemToggleCard(
                    title: "BRAIN CAPITAL ALERT",
                    subtitle: "Sends a notification to your phone if the brain finds a strong buy but there is not enough capital available.",
                    tint: WealthTheme.cyan,
                    isOn: $protection.capitalAlertEnabled
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("ACCOUNT RESET")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("Resets capital, portfolio, queue, reserves, and profit totals back to zero for a clean AI test run.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(cardShell(cornerRadius: 18))

                Button {
                    WealthAppSessionController.shared.resetAccountAndVisibleAppStateToZero()
                } label: {
                    Text("RESET TO ZERO")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(WealthTheme.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.cyan, secondaryTint: WealthTheme.green))
    }

    private var cycleSummaryCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Cycle")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(engine.lockedCheckpointProgress)/\(WealthEngineStore.lockedCheckpointCount)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundColor(WealthTheme.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(sectionGlowShell(cornerRadius: 11, tint: WealthTheme.cyan))
    }

    private var startupDownloadTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DOWNLOAD BOARD")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                solidPill(serialDownloadStatus, color: serialDownloadTint, darkText: true)
            }

            ForEach(startupStatusRows) { row in
                startupStatusRow(row)
            }
        }
        .padding(12)
        .background(cardShell(cornerRadius: 18))
    }
}
