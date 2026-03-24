import Foundation

extension WealthEngineStore {
    var softRefreshInterval: TimeInterval {
        configuredSoftRefreshMinutes * 60
    }

    var heavyRefreshInterval: TimeInterval {
        configuredHeavyRefreshMinutes * 60
    }

    func recoverLiveUpdatesIfNeeded(reason: String, now: Date = .now) {
        handleDayRolloverIfNeeded(now: now)

        if !hasBootstrapped || activationTask != nil || pendingRefreshPayload != nil || pendingPublishTask != nil {
            return
        }

        let portfolio = WealthPortfolioStore.shared
        let pendingLifecycleThreshold: TimeInterval = 20
        let staleThreshold = max(softRefreshInterval + 10, 45)

        if softTimer == nil || heavyTimer == nil {
            rescheduleTimers()
        }

        guard let lastRefresh else {
            refresh(mode: .deep)
            return
        }

        if portfolio.hasPendingBrokerLifecycleWork,
           now.timeIntervalSince(lastRefresh) >= pendingLifecycleThreshold {
            lastDecisionSummary = "Reconciling pending broker activity after \(reason)"
            refresh(mode: .quick)
            return
        }

        guard now.timeIntervalSince(lastRefresh) >= staleThreshold else { return }

        lastDecisionSummary = "Recovering live scan after \(reason)"
        refresh(mode: .soft, countsTowardDailyCycles: true)
    }
}
