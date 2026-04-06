import Foundation

extension WealthEngineStore {
    var softRefreshInterval: TimeInterval {
        configuredSoftRefreshMinutes * 60
    }

    var heavyRefreshInterval: TimeInterval {
        configuredHeavyRefreshMinutes * 60
    }

    func recoverLiveUpdatesIfNeeded(reason: String, now: Date = .now) {
        let didRollOver = handleDayRolloverIfNeeded(now: now)

        if !hasBootstrapped || activationTask != nil || pendingRefreshPayload != nil || pendingPublishTask != nil {
            return
        }

        if scheduledCheckpointTimer == nil {
            rescheduleTimers()
        }

        if didRollOver {
            lastDecisionSummary = "Starting new trading day after \(reason)"
            rescheduleTimers()
            return
        }

        if requiresDownstreamLiveRecovery(now: now) {
            downstreamRecoveryPending = true
            runActivationSequence()
            return
        }

        if downstreamRecoveryPending {
            downstreamRecoveryPending = false
        }
    }
}
