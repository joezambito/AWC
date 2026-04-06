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

    private var serialDownloadStatus: String {
        if engine.startupSequenceInFlight { return "SERIAL" }
        if activationCycleComplete { return "READY" }
        return "WAITING"
    }

    private var serialDownloadTint: Color {
        if engine.startupSequenceInFlight { return WealthTheme.cyan }
        if activationCycleComplete { return WealthTheme.green }
        return WealthTheme.grey
    }

    private var startupStatusRows: [StartupStatusRow] {
        [
            StartupStatusRow(
                id: "app_open",
                title: "APP OPEN",
                status: appOpenStatus,
                detail: appOpenDetail,
                timeText: appOpenTimeText,
                tint: appOpenTint
            ),
            StartupStatusRow(
                id: "universe",
                title: "UNIVERSE",
                status: universeStatus,
                detail: universeDetail,
                timeText: universeTimeText,
                tint: universeTint
            ),
            StartupStatusRow(
                id: "ai_scan",
                title: "AI SCAN",
                status: aiScanStatus,
                detail: aiScanDetail,
                timeText: aiScanTimeText,
                tint: aiScanTint
            ),
            StartupStatusRow(
                id: "market",
                title: "MARKET",
                status: marketStatus,
                detail: marketDetail,
                timeText: marketTimeText,
                tint: marketTint
            ),
            StartupStatusRow(
                id: "broker_quotes",
                title: "BROKER QUOTES",
                status: brokerQuoteStatus,
                detail: brokerQuoteDetail,
                timeText: brokerQuoteTimeText,
                tint: brokerQuoteTint
            ),
            StartupStatusRow(
                id: "research",
                title: "RESEARCH FEEDS",
                status: researchFeedStatus,
                detail: researchFeedDetail,
                timeText: researchFeedTimeText,
                tint: researchFeedTint
            )
        ]
    }

    private var appOpenStatus: String {
        if engine.appOpenUpdatedAt != nil || engine.cacheRestoreUpdatedAt != nil || engine.startupSequenceInFlight || activationCycleComplete {
            return "DONE"
        }
        return "WAITING"
    }

    private var appOpenDetail: String {
        if engine.cacheRestoreUpdatedAt != nil {
            return "Phone opened from cache and is holding the rest of startup behind the staged startup flow."
        }
        return "Phone shell opened and startup sequencing is now allowed to continue."
    }

    private var appOpenTimeText: String {
        WealthFormat.clock(engine.appOpenUpdatedAt ?? engine.cacheRestoreUpdatedAt ?? engine.startupSequenceUpdatedAt)
    }

    private var appOpenTint: Color {
        appOpenStatus == "DONE" ? WealthTheme.green : WealthTheme.grey
    }

    private var universeStatus: String {
        switch engine.startupSequencePhase {
        case .waitingToScan:
            return "QUEUED"
        case .universeRefreshRunning:
            return "RUNNING"
        case .aiScanRunning, .postScanHold, .marketWarmupRunning:
            return "DONE"
        case .idle:
            if universeStore.isLoading { return "RUNNING" }
            if universeStore.sourceLabel == "CACHED SNAPSHOT" || !universeStore.records.isEmpty { return "DONE" }
            if universeStore.lastSuccessfulLoadAt != nil { return "DONE" }
            return "WAITING"
        }
    }

    private var universeDetail: String {
        switch engine.startupSequencePhase {
        case .waitingToScan:
            return "Universe refresh is queued behind the 2 second startup hold."
        case .universeRefreshRunning:
            return "Universe is refreshing card inputs before the startup AI scan can begin."
        case .aiScanRunning, .postScanHold, .marketWarmupRunning:
            return "Universe finished and handed off to the startup AI scan."
        case .idle:
            if universeStore.isLoading {
                return "Universe is refreshing card inputs before the startup AI scan can begin."
            }
            if universeStore.sourceLabel == "CACHED SNAPSHOT" {
                return "Universe reused the saved snapshot for this open instead of running a new full refresh."
            }
            if universeStore.lastSuccessfulLoadAt != nil || !universeStore.records.isEmpty {
                return "Universe refresh completed and card inputs are ready."
            }
            return "Universe waits for app open."
        }
    }

    private var universeTimeText: String {
        if universeStore.sourceLabel == "CACHED SNAPSHOT" {
            return "CACHED"
        }
        return WealthFormat.clock(universeStore.lastSuccessfulLoadAt ?? engine.startupSequenceUpdatedAt)
    }

    private var universeTint: Color {
        switch universeStatus {
        case "RUNNING":
            return WealthTheme.blue
        case "DONE":
            return WealthTheme.green
        case "QUEUED":
            return WealthTheme.cyan
        default:
            return WealthTheme.grey
        }
    }

    private var aiScanStatus: String {
        switch engine.startupSequencePhase {
        case .waitingToScan, .universeRefreshRunning:
            return "WAITING"
        case .aiScanRunning, .postScanHold:
            return "RUNNING"
        case .marketWarmupRunning:
            return "DONE"
        case .idle:
            return activationCycleComplete || engine.lastRefresh != nil ? "DONE" : "WAITING"
        }
    }

    private var aiScanDetail: String {
        switch engine.startupSequencePhase {
        case .waitingToScan:
            return "Waiting for the 2 second startup hold to finish before the universe step."
        case .universeRefreshRunning:
            return "AI scan is waiting for the universe step to finish."
        case .aiScanRunning:
            return "Scoring and confidence scan is running for the startup pass."
        case .postScanHold:
            return "AI pass finished and pending publish is being held briefly before market warmup."
        case .marketWarmupRunning:
            return "Startup AI pass finished and handed off to market warmup."
        case .idle:
            return activationCycleComplete || engine.lastRefresh != nil
                ? "Startup AI pass is complete."
                : "AI pass is waiting for app open."
        }
    }

    private var aiScanTimeText: String {
        if activationCycleComplete || engine.lastRefresh != nil {
            return WealthFormat.clock(engine.lastRefresh)
        }
        return WealthFormat.clock(engine.startupSequenceUpdatedAt)
    }

    private var aiScanTint: Color {
        switch aiScanStatus {
        case "RUNNING":
            return WealthTheme.orange
        case "DONE":
            return WealthTheme.green
        case "QUEUED":
            return WealthTheme.cyan
        default:
            return WealthTheme.grey
        }
    }

    private var marketStatus: String {
        switch engine.startupSequencePhase {
        case .marketWarmupRunning:
            return "RUNNING"
        case .idle:
            if engine.isMarketMaterializationInFlight { return "RUNNING" }
            if engine.downstreamRecoveryPending { return "WAITING" }
            if marketCycleStore.cycleMarker != nil || engine.marketMaterializationUpdatedAt > engine.startupSequenceUpdatedAt {
                return "DONE"
            }
            return "WAITING"
        default:
            return "WAITING"
        }
    }

    private var marketDetail: String {
        if engine.startupSequencePhase == .marketWarmupRunning || engine.isMarketMaterializationInFlight {
            return "Building the ranked market view after the universe and AI stages are complete."
        }
        if marketCycleStore.cycleMarker != nil {
            return "Top-100 market panel is ready from the latest ranked market cycle."
        }
        return "Market warmup waits until the startup AI scan and pending publish are done."
    }

    private var marketTimeText: String {
        WealthFormat.clock(marketCycleStore.cycleMarker ?? engine.marketMaterializationUpdatedAt)
    }

    private var marketTint: Color {
        switch marketStatus {
        case "RUNNING":
            return WealthTheme.cyan
        case "DONE":
            return WealthTheme.green
        default:
            return WealthTheme.grey
        }
    }

    private var brokerQuoteStatus: String {
        if liveMarketStore.twsConnected {
            return liveMarketStore.lastTickReceivedAt == nil ? "RUNNING" : "LIVE"
        }
        if syncStore.isTWSConnectedForQuotes {
            return liveMarketStore.lastTickReceivedAt == nil ? "WAITING" : "DELAYED"
        }
        if syncStore.syncStatus.contains("FAILED") {
            return "FAILED"
        }
        return syncStore.syncStatus == "TWS OFFLINE" ? "OFFLINE" : syncStore.syncStatus
    }

    private var brokerQuoteDetail: String {
        if liveMarketStore.twsConnected {
            return liveMarketStore.lastTickReceivedAt == nil
                ? "Broker link is up and waiting for the first quote tick."
                : "Quote feed is active and market prices are arriving."
        }
        if syncStore.isTWSConnectedForQuotes {
            return "Broker link is available with delayed or bridged quote support."
        }
        return "Broker quote download path follows the TWS connection state."
    }

    private var brokerQuoteTimeText: String {
        WealthFormat.clock(liveMarketStore.lastTickReceivedAt ?? syncStore.syncStatusUpdatedAt)
    }

    private var brokerQuoteTint: Color {
        switch brokerQuoteStatus {
        case "LIVE":
            return WealthTheme.green
        case "DELAYED", "RUNNING", "WAITING", "CONNECTING":
            return WealthTheme.cyan
        case "FAILED":
            return WealthTheme.red
        default:
            return WealthTheme.grey
        }
    }

    private var researchFeedStatus: String {
        let states = Array(providerStore.sourceStatesByKind.values)
        let enabledKinds = WealthExternalResearchKind.allCases.filter { providerStore.isEnabled($0) }
        let hasLiveEndpointConfigured = enabledKinds.contains { providerStore.hasConfiguredEndpoint(for: $0) }
        if states.contains(.freshOnline) { return "SUCCESS" }
        if states.contains(.cached) { return "CACHED" }
        if states.contains(.syntheticFallback), !hasLiveEndpointConfigured { return "NO LIVE CONFIG" }
        if states.contains(.syntheticFallback) { return "FALLBACK" }
        if states.contains(.unavailable) { return "FAILED" }
        return "WAITING"
    }

    private var researchFeedDetail: String {
        let activeKinds = providerStore.sourceStatesByKind.count
        switch researchFeedStatus {
        case "SUCCESS":
            return "External research downloads completed with live provider data across \(activeKinds) feeds."
        case "CACHED":
            return "Research refresh kept cached provider values when live fetches were not available."
        case "NO LIVE CONFIG":
            return "No live paid provider endpoints are configured, so research is using the built-in fallback feed by design."
        case "FALLBACK":
            return "Research layer is running on fallback or mock values instead of a live provider response."
        case "FAILED":
            return "At least one enabled research feed reported unavailable during the last refresh."
        default:
            return "Research feeds will update during the next AI scan."
        }
    }

    private var researchFeedTimeText: String {
        WealthFormat.clock(providerStore.lastResearchRefreshAt)
    }

    private var researchFeedTint: Color {
        switch researchFeedStatus {
        case "SUCCESS":
            return WealthTheme.green
        case "CACHED":
            return WealthTheme.cyan
        case "NO LIVE CONFIG":
            return WealthTheme.orange
        case "FALLBACK":
            return WealthTheme.orange
        case "FAILED":
            return WealthTheme.red
        default:
            return WealthTheme.grey
        }
    }

    private func startupStatusRow(_ row: StartupStatusRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(row.title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Text(row.detail)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                solidPill(row.status, color: row.tint, darkText: row.tint != WealthTheme.blue)
                Text(row.timeText)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(row.tint)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .background(sectionGlowShell(cornerRadius: 16, tint: row.tint))
    }
}
