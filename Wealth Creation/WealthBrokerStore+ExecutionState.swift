import Foundation

@MainActor
extension WealthBrokerStore {
    var readinessBadge: String {
        if liveExecutionArmed {
            return "LIVE ARMED"
        }
        if paperExecutionReady {
            return "PAPER READY"
        }
        if liveTradingEnabled {
            return "LIVE STAGED"
        }
        return "OFFLINE"
    }

    var executionModeLabel: String {
        if liveExecutionArmed {
            return "Live broker"
        }
        if paperExecutionReady {
            return "Paper broker"
        }
        return "Broker offline"
    }

    var paperExecutionReady: Bool {
        paperTradingEnabled
    }

    var liveExecutionArmed: Bool {
        liveTradingEnabled && !paperTradingEnabled && WealthSyncStore.shared.liveMode
    }

    var executionEnabled: Bool {
        paperExecutionReady || liveExecutionArmed
    }

    var executionCashBalance: Double {
        guard executionEnabled else { return 0 }
        return liveExecutionArmed ? ibkrLiveBalance : ibkrPaperBalance
    }

    var rejectionCooldownActive: Bool {
        guard let lastBrokerFailureAt else { return false }
        return Date().timeIntervalSince(lastBrokerFailureAt) < (15 * 60)
    }

    func clearBrokerFailureState() {
        lastBrokerFailureAt = nil
        lastBrokerFailureReason = ""
    }

    func recordBrokerFailure(_ detail: String) {
        lastBrokerFailureAt = .now
        lastBrokerFailureReason = detail
    }
}
