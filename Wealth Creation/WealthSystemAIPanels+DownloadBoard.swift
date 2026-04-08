import SwiftUI

extension WealthSystemAIStatusPanel {
    var serialDownloadStatus: String {
        if engine.startupSequenceInFlight { return "SERIAL" }
        if activationCycleComplete { return "READY" }
        return "WAITING"
    }

    var serialDownloadTint: Color {
        if engine.startupSequenceInFlight { return WealthTheme.cyan }
        if activationCycleComplete { return WealthTheme.green }
        return WealthTheme.grey
    }

    var startupStatusRows: [StartupStatusRow] {
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

    var appOpenStatus: String {
        if engine.appOpenUpdatedAt != nil || engine.cacheRestoreUpdatedAt != nil || engine.startupSequenceInFlight || activationCycleComplete {
            return "DONE"
        }
        return "WAITING"
    }

    var appOpenDetail: String {
        if engine.cacheRestoreUpdatedAt != nil {
            return "Phone opened from cache and is holding the rest of startup behind the staged startup flow."
        }
        return "Phone shell opened and startup sequencing is now allowed to continue."
    }

    var appOpenTimeText: String {
        WealthFormat.clock(engine.appOpenUpdatedAt ?? engine.cacheRestoreUpdatedAt ?? engine.startupSequenceUpdatedAt)
    }

    var appOpenTint: Color {
        appOpenStatus == "DONE" ? WealthTheme.green : WealthTheme.grey
    }

    var universeStatus: String {
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

    var universeDetail: String {
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

    var universeTimeText: String {
        if universeStore.sourceLabel == "CACHED SNAPSHOT" {
            return "CACHED"
        }
        return WealthFormat.clock(universeStore.lastSuccessfulLoadAt ?? engine.startupSequenceUpdatedAt)
    }

    var universeTint: Color {
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

    var aiScanStatus: String {
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

    var aiScanDetail: String {
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

    var aiScanTimeText: String {
        if activationCycleComplete || engine.lastRefresh != nil {
            return WealthFormat.clock(engine.lastRefresh)
        }
        return WealthFormat.clock(engine.startupSequenceUpdatedAt)
    }

    var aiScanTint: Color {
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
}
