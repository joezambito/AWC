import SwiftUI

extension WealthEngineStore {
    func refresh(
        mode: RefreshMode,
        countsTowardDailyCycles: Bool = false,
        publishToUI: Bool = true
    ) {
        resetDailyCycleCountIfNeeded()

        let refreshTime = Date()
        let context = refreshContext(at: refreshTime)
        let modeLabel = refreshModeLabel(mode)
        let openingCycleRefresh = activationTask != nil || (!tradingLifecycleArmed && !activationCycleComplete)

        WealthEventLogStore.shared.record(
            title: "Refresh Start",
            detail: "\(modeLabel) scan started across \(context.scannedMarkets.count) world markets with \(context.activeMarkets.count) on live execution focus.",
            category: "scan",
            tintName: "cyan"
        )

        if openingCycleRefresh {
            setActivationState(for: mode)
        } else {
            activationStage = 0
            activationCycleComplete = true
        }

        let stagedBlueprints = WealthEngineRefreshStaging.stagedBlueprints(
            mode: mode,
            seededBlueprints: Self.seededBlueprints(),
            scannedMarkets: context.scannedMarkets,
            protectedKeys: context.protectedKeys
        )

        guard !stagedBlueprints.isEmpty else {
            applyEmptyRefreshState(
                mode: mode,
                refreshTime: refreshTime,
                countsTowardDailyCycles: countsTowardDailyCycles,
                publishToUI: publishToUI
            )
            return
        }

        let previewBlueprints = stagedBlueprints.map {
            $0.applyingExternalSignal(context.externalData.normalizedSignal(for: $0))
        }
        let regime = Self.marketRegime(for: previewBlueprints, goals: context.goals)
        let brainMode = Self.aggressionMode(for: context.goals)
        let hungerMode = Self.hungerMode(for: context.goals, mode: brainMode)

        let opportunities = WealthEngineRefreshRanking.buildRankedAssets(
            stagedBlueprints: stagedBlueprints,
            activeMarkets: context.activeMarkets,
            protectedKeys: context.protectedKeys,
            previousByKey: context.previousByKey,
            refreshTime: refreshTime,
            brokerStore: context.brokerStore,
            externalData: context.externalData,
            goals: context.goals,
            behavior: context.behaviorStore,
            buyingPower: context.buyingPower,
            regime: regime,
            holdings: context.holdings,
            currentOpenPositions: context.currentOpenPositions,
            dailyLossLocked: context.dailyLossLocked,
            marketWideBrake: context.marketWideBrake,
            brokerCooldownActive: context.brokerCooldownActive
        )

        let payload = PendingRefreshPayload(
            opportunities: opportunities,
            mode: mode,
            refreshTime: refreshTime,
            buyingPower: context.buyingPower,
            goals: context.goals,
            regime: regime,
            brainMode: brainMode,
            hungerMode: hungerMode,
            scannedSignals: scannedSignalsForMode(mode, opportunities: opportunities)
        )

        updateRecurringCycleState(
            mode: mode,
            refreshTime: refreshTime,
            countsTowardDailyCycles: countsTowardDailyCycles
        )

        pendingRefreshPayload = payload
        lastDecisionSummary = openingCycleRefresh
            ? "AI scan \(activationStage)/\(activationStageTotal) running. Results stay frozen until the cycle finishes."
            : "\(modeLabel) scan running. Results stay frozen until the cycle finishes."

        if publishToUI {
            schedulePendingRefreshPublish()
        }

        WealthEventLogStore.shared.record(
            title: "Refresh Complete",
            detail: publishToUI
                ? "\(modeLabel) scan finished. UI stays frozen until the 2 second publish delay ends."
                : "\(modeLabel) scan stage finished. UI remains frozen until the full cycle completes.",
            category: "refresh",
            tintName: "orange",
            timestamp: refreshTime
        )
    }

    func applyPendingRefreshState() {
        guard let payload = pendingRefreshPayload else { return }
        pendingPublishTask?.cancel()
        pendingPublishTask = nil
        pendingRefreshPayload = nil
        applyResolvedRefresh(payload)
    }

    func updateRecurringCycleState(
        mode: RefreshMode,
        refreshTime: Date,
        countsTowardDailyCycles: Bool
    ) {
        if countsTowardDailyCycles, let recurringKind = recurringCycleKind(for: mode) {
            recordRecurringCycle(recurringKind, now: refreshTime)
            WealthEventLogStore.shared.record(
                title: recurringKind == .soft ? "Soft Scan" : "Hard Scan",
                detail: "\(recurringKind.rawValue) cycle recorded at \(WealthFormat.clock(refreshTime)).",
                category: "scan",
                tintName: recurringKind == .soft ? "green" : "orange",
                timestamp: refreshTime
            )
            return
        }

        if mode == .deep {
            lastRecurringCycleLabel = "DEEP"
            defaults.set("DEEP", forKey: StorageKey.lastRecurringCycleLabel)
        }
    }
}
