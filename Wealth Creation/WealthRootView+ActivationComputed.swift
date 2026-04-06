import SwiftUI

extension WealthRootView {
    var activationCycleTint: Color {
        if engine.activationCycleComplete { return WealthTheme.green }
        switch engine.startupSequencePhase {
        case .universeRefreshRunning:
            return WealthTheme.blue
        case .marketWarmupRunning:
            return WealthTheme.cyan
        default:
            break
        }
        if engine.activationStage == 0 { return WealthTheme.grey }

        switch engine.activationStage {
        case 1: return WealthTheme.orange
        case 2: return WealthTheme.green
        default: return WealthTheme.grey
        }
    }

    var activationCycleLabel: String {
        if engine.activationCycleComplete { return "AI UPDATED" }
        switch engine.startupSequencePhase {
        case .universeRefreshRunning:
            return "UNIVERSE"
        case .marketWarmupRunning:
            return "MARKET"
        default:
            break
        }
        if engine.activationStage == 0 {
            return engine.lastRefresh == nil ? "AI SCAN" : "AI UPDATED"
        }
        return "AI SCAN"
    }

    var activationCycleDetail: String {
        let lockedCountText = "\(max(engine.lockedCheckpointProgress, engine.activationCycleComplete ? WealthEngineStore.lockedCheckpointCount : 0))/\(WealthEngineStore.lockedCheckpointCount)"

        if engine.activationCycleComplete { return lockedCountText }
        switch engine.startupSequencePhase {
        case .universeRefreshRunning, .marketWarmupRunning:
            return lockedCountText
        default:
            break
        }
        if engine.activationStage == 0 {
            return engine.lastRefresh == nil ? lockedCountText : lockedCountText
        }
        return lockedCountText
    }

    var activationCycleModeLabel: String {
        switch engine.startupSequencePhase {
        case .universeRefreshRunning:
            return "UNIVERSE"
        case .marketWarmupRunning:
            return "MARKET"
        default:
            break
        }
        switch engine.activationStage {
        case 1: return "PREP"
        case 2: return "AI SCAN"
        default: return "AI SCAN"
        }
    }

    var activationCycleSummary: String {
        if engine.activationCycleComplete {
            let heavyText = engine.lastHeavyRefresh.map { WealthFormat.clock($0) } ?? "--:--:--"
            return "Brain cycle complete. Last heavy cycle finished at \(heavyText). Soft cycle refreshes every \(Int(lightRefreshMinutes))m and heavy cycle refreshes every \(Int(heavyRefreshMinutes))m."
        }

        switch engine.startupSequencePhase {
        case .universeRefreshRunning:
            return "Universe update is running now. The phone is holding the market warmup until the universe refresh finishes."
        case .marketWarmupRunning:
            return "Market warmup is building the ranked top-100 view from the refreshed green-card feed."
        default:
            break
        }

        switch engine.activationStage {
        case 0:
            return "AI scan is lining up the next cycle before the dashboard updates."
        case 1:
            return "Opening cycle is restoring the phone snapshot and preparing the scan."
        case 2:
            return "Current pass: final AI scan. When it finishes, the phone waits briefly and then swaps in the new data."
        default:
            return "The brain is preparing the next cycle."
        }
    }
}
