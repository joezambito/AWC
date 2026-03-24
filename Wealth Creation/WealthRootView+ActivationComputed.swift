import SwiftUI

extension WealthRootView {
    var activationCycleTint: Color {
        if engine.activationCycleComplete { return WealthTheme.green }
        if engine.activationStage == 0 { return WealthTheme.grey }

        switch engine.activationStage {
        case 1: return WealthTheme.orange
        case 2: return WealthTheme.green
        default: return WealthTheme.grey
        }
    }

    var activationCycleLabel: String {
        if engine.activationCycleComplete { return "AI UPDATED" }
        if engine.activationStage == 0 {
            return engine.lastRefresh == nil ? "AI SCAN" : "AI UPDATED"
        }
        return "AI SCAN"
    }

    var activationCycleDetail: String {
        if engine.activationCycleComplete { return "" }
        if engine.activationStage == 0 {
            return engine.lastRefresh == nil ? "0/\(engine.activationStageTotal)" : ""
        }
        return "\(engine.activationStage)/\(engine.activationStageTotal)"
    }

    var activationCycleModeLabel: String {
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
