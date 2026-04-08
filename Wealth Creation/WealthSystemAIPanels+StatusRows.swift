import SwiftUI

extension WealthSystemAIStatusPanel {
    var marketStatus: String {
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

    var marketDetail: String {
        if engine.startupSequencePhase == .marketWarmupRunning || engine.isMarketMaterializationInFlight {
            return "Building the ranked market view after the universe and AI stages are complete."
        }
        if marketCycleStore.cycleMarker != nil {
            return "Top-100 market panel is ready from the latest ranked market cycle."
        }
        return "Market warmup waits until the startup AI scan and pending publish are done."
    }

    var marketTimeText: String {
        WealthFormat.clock(marketCycleStore.cycleMarker ?? engine.marketMaterializationUpdatedAt)
    }

    var marketTint: Color {
        switch marketStatus {
        case "RUNNING":
            return WealthTheme.cyan
        case "DONE":
            return WealthTheme.green
        default:
            return WealthTheme.grey
        }
    }

    var brokerQuoteStatus: String {
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

    var brokerQuoteDetail: String {
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

    var brokerQuoteTimeText: String {
        WealthFormat.clock(liveMarketStore.lastTickReceivedAt ?? syncStore.syncStatusUpdatedAt)
    }

    var brokerQuoteTint: Color {
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

    var researchFeedStatus: String {
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

    var researchFeedDetail: String {
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

    var researchFeedTimeText: String {
        WealthFormat.clock(providerStore.lastResearchRefreshAt)
    }

    var researchFeedTint: Color {
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

    func startupStatusRow(_ row: StartupStatusRow) -> some View {
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
