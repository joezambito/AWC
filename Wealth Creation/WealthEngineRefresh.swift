import SwiftUI

extension WealthEngineStore {
    func runStartupActivationScan() async {
        guard !isDashboardRefreshInFlight else { return }
        pendingRefreshPayload = nil

        let refreshTime = Date()
        let context = refreshContext(at: refreshTime)
        let modeLabel = refreshModeLabel(.startup)

        WealthEventLogStore.shared.record(
            title: "AI Startup Scan",
            detail: "Startup AI scan began after the 2 second phone hold.",
            category: "scan",
            tintName: "cyan",
            timestamp: refreshTime
        )

        let seededBlueprints = Self.seededBlueprints()
        let stagedBlueprints = WealthEngineRefreshStaging.stagedBlueprints(
            mode: .startup,
            seededBlueprints: seededBlueprints,
            scannedMarkets: context.scannedMarkets,
            protectedKeys: context.protectedKeys
        )

        guard !stagedBlueprints.isEmpty else {
            WealthEventLogStore.shared.record(
                title: "AI Startup Empty",
                detail: "Startup AI scan found no staged blueprints.",
                category: "scan",
                tintName: "orange",
                timestamp: refreshTime
            )
            endDashboardRefreshFreeze()
            return
        }

        let researchStartedAt = CFAbsoluteTimeGetCurrent()
        await context.externalData.refreshResearchInputs(
            for: stagedBlueprints,
            modeLabel: modeLabel,
            refreshTime: refreshTime
        )
        let _ = CFAbsoluteTimeGetCurrent() - researchStartedAt

        let previewBlueprints = stagedBlueprints.map {
            $0.applyingExternalSignal(context.externalData.normalizedSignal(for: $0))
        }
        let regime = Self.marketRegime(for: previewBlueprints, goals: context.goals)
        let brainMode = Self.aggressionMode(for: context.goals)
        let hungerMode = Self.hungerMode(for: context.goals, mode: brainMode)

        let opportunities = WealthEngineRefreshRanking.buildRankedAssets(
            mode: .startup,
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

        pendingRefreshPayload = PendingRefreshPayload(
            opportunities: opportunities,
            mode: .startup,
            refreshTime: refreshTime,
            buyingPower: context.buyingPower,
            goals: context.goals,
            regime: regime,
            brainMode: brainMode,
            hungerMode: hungerMode,
            scannedSignals: scannedSignalsForMode(.startup, opportunities: opportunities)
        )

        startupSequencePhase = .postScanHold

        WealthEventLogStore.shared.record(
            title: "AI Startup Ready",
            detail: "Startup AI scan finished and staged for delayed publish.",
            category: "scan",
            tintName: "orange",
            timestamp: refreshTime
        )
        WealthEventLogStore.shared.record(
            title: "Refresh Complete",
            detail: "\(modeLabel) scan staged for delayed publish.",
            category: "refresh",
            tintName: "orange",
            timestamp: refreshTime
        )
    }

    func refresh(
        mode: RefreshMode,
        countsTowardDailyCycles: Bool = false,
        publishToUI: Bool = true
    ) {
        Task { @MainActor [weak self] in
            await self?.refreshAsync(
                mode: mode,
                countsTowardDailyCycles: countsTowardDailyCycles,
                publishToUI: publishToUI
            )
        }
    }

    func refreshAsync(
        mode: RefreshMode,
        countsTowardDailyCycles: Bool = false,
        publishToUI: Bool = true
    ) async {
        let brokerReady = WealthIBKRBridge.shared.apiReady
        let refreshStartedAt = CFAbsoluteTimeGetCurrent()

        if !publishToUI && activationTask == nil {
            WealthEventLogStore.shared.record(
                title: "Warm Refresh Background Scope",
                detail: "Silent warm refresh is using capped background scope to keep launch responsive while cached UI stays visible.",
                category: "refresh",
                tintName: "orange",
                timestamp: .now
            )
        }

        if publishToUI {
            guard !isDashboardRefreshInFlight else { return }
            beginDashboardRefreshFreezeIfNeeded()
            startScanProgressAnimation(for: mode)
        }

        resetDailyCycleCountIfNeeded()

        let refreshTime = Date()
        let context = refreshContext(at: refreshTime)
        let modeLabel = refreshModeLabel(mode)
        let seededBlueprints = Self.seededBlueprints()

        WealthPipelineTraceLogger.logSymbolTrace(
            rawBrokerSymbols: WealthLiveMarketDataStore.shared.rawBrokerSymbolCount,
            rawQuoteSymbols: WealthBrokerQuoteStore.shared.rawQuoteSymbolCount
        )
        WealthPipelineTraceLogger.logSeedUniverse(seededBlueprints)
        WealthPipelineTraceLogger.logUniverse(seededBlueprints)

        WealthEventLogStore.shared.record(
            title: "Refresh Start",
            detail: "\(modeLabel) scan started across \(context.scannedMarkets.count) world markets with \(context.activeMarkets.count) on live execution focus.",
            category: "scan",
            tintName: "cyan",
            timestamp: refreshTime
        )

        if !brokerReady {
            WealthEventLogStore.shared.record(
                title: "IBKR Not Ready",
                detail: "\(modeLabel) scan continuing without IBKR burst support.",
                category: "scan",
                tintName: "orange",
                timestamp: refreshTime
            )
        }

        let stagedBlueprints = WealthEngineRefreshStaging.stagedBlueprints(
            mode: mode,
            seededBlueprints: seededBlueprints,
            scannedMarkets: context.scannedMarkets,
            protectedKeys: context.protectedKeys
        )
        let scopedBlueprints = scopedRefreshBlueprints(
            stagedBlueprints,
            mode: mode,
            publishToUI: publishToUI
        )

        guard !scopedBlueprints.isEmpty else {
            WealthEventLogStore.shared.record(
                title: "Refresh Empty",
                detail: "\(modeLabel) scan found no staged blueprints.",
                category: "refresh",
                tintName: "orange",
                timestamp: refreshTime
            )
            applyEmptyRefreshState(
                mode: mode,
                refreshTime: refreshTime,
                countsTowardDailyCycles: countsTowardDailyCycles,
                publishToUI: publishToUI
            )
            return
        }

        let shouldRunInlineBurst = brokerReady && !countsTowardDailyCycles && mode != .soft && mode != .heavy
        if shouldRunInlineBurst {
            let access = await WealthSyncStore.shared.ensureScanBrokerAccess(
                reason: "\(modeLabel.lowercased()) inline burst",
                blueprints: scopedBlueprints
            )
            if access == .startedBurst {
                WealthSyncStore.shared.scheduleScanBrokerBurstStop()
            }
        }

        let researchStartedAt = CFAbsoluteTimeGetCurrent()
        await context.externalData.refreshResearchInputs(
            for: scopedBlueprints,
            modeLabel: modeLabel,
            refreshTime: refreshTime
        )
        let researchDuration = CFAbsoluteTimeGetCurrent() - researchStartedAt

        let previewBlueprints = scopedBlueprints.map {
            $0.applyingExternalSignal(context.externalData.normalizedSignal(for: $0))
        }
        let regime = Self.marketRegime(for: previewBlueprints, goals: context.goals)
        let brainMode = Self.aggressionMode(for: context.goals)
        let hungerMode = Self.hungerMode(for: context.goals, mode: brainMode)

        let rankingStartedAt = CFAbsoluteTimeGetCurrent()
        let opportunities = WealthEngineRefreshRanking.buildRankedAssets(
            mode: mode,
            stagedBlueprints: scopedBlueprints,
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

        let rankingDuration = CFAbsoluteTimeGetCurrent() - rankingStartedAt

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

        if mode == .soft && publishToUI {
            pendingRefreshPayload = payload
            WealthEventLogStore.shared.record(
                title: "Refresh Complete",
                detail: "\(modeLabel) scan staged for delayed publish.",
                category: "refresh",
                tintName: "orange",
                timestamp: refreshTime
            )
            return
        }

        if publishToUI {
            var noAnimationTransaction = Transaction(animation: nil)
            noAnimationTransaction.disablesAnimations = true

            await applyResolvedRefreshSequence(payload)

            withTransaction(noAnimationTransaction) {
                if let stagedDashboardSnapshot {
                    dashboardSnapshot = stagedDashboardSnapshot
                }

                self.scanProgressAnimationTask?.cancel()
                self.scanProgressAnimationTask = nil
                self.scanProgressAnimationEndsAt = nil
                self.stagedDashboardSnapshot = nil
                endDashboardRefreshFreeze()
            }
        } else {
            persistBackgroundRefreshCache(payload)
        }

        let totalDuration = CFAbsoluteTimeGetCurrent() - refreshStartedAt
        WealthEventLogStore.shared.record(
            title: "Refresh Complete",
            detail: publishToUI
                ? "\(modeLabel) scan finished and published immediately."
                : "\(modeLabel) scan stage finished and applied immediately.",
            category: "refresh",
            tintName: "orange",
            timestamp: refreshTime
        )
        WealthEventLogStore.shared.record(
            title: "Refresh Timing",
            detail: "\(modeLabel) stage=\(scopedBlueprints.count) research=\(Int(researchDuration.rounded()))s rank=\(Int(rankingDuration.rounded()))s total=\(Int(totalDuration.rounded()))s.",
            category: "refresh",
            tintName: publishToUI ? "cyan" : "blue",
            timestamp: refreshTime
        )
    }

    func applyPendingRefreshState() async {
        guard let payload = pendingRefreshPayload else {
            endDashboardRefreshFreeze()
            return
        }
        await applyPendingRefreshState(payload)
    }

    func applyPendingRefreshState(_ payload: PendingRefreshPayload) async {
        pendingPublishTask?.cancel()
        pendingPublishTask = nil

        var noAnimationTransaction = Transaction(animation: nil)
        noAnimationTransaction.disablesAnimations = true

        await applyResolvedRefreshSequence(payload)

        withTransaction(noAnimationTransaction) {
            if let stagedDashboardSnapshot {
                dashboardSnapshot = stagedDashboardSnapshot
            }

            self.scanProgressAnimationTask?.cancel()
            self.scanProgressAnimationTask = nil
            self.scanProgressAnimationEndsAt = nil
            self.stagedDashboardSnapshot = nil
            endDashboardRefreshFreeze()
        }

        pendingRefreshPayload = nil
    }

    private func scopedRefreshBlueprints(
        _ stagedBlueprints: [OpportunityBlueprint],
        mode: RefreshMode,
        publishToUI: Bool
    ) -> [OpportunityBlueprint] {
        guard !publishToUI else { return stagedBlueprints }
        guard activationTask == nil else { return stagedBlueprints }
        guard hasUsableWarmStartCardCache else { return stagedBlueprints }

        switch mode {
        case .soft:
            return Array(stagedBlueprints.prefix(600))
        case .heavy, .deep:
            return Array(stagedBlueprints.prefix(900))
        case .startup, .quick:
            return stagedBlueprints
        }
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

private func marketCountSummary(for blueprints: [OpportunityBlueprint]) -> String {
    let keyRegions = ["AU", "US", "CA", "EU", "APAC"]
    let marketCounts = Dictionary(grouping: blueprints, by: \.market).mapValues(\.count)
    let regionCounts = Dictionary(
        grouping: blueprints,
        by: { WealthMarketLabels.region(for: $0.market) }
    ).mapValues(\.count)

    let regionSummary = keyRegions
        .map { "\($0)=\(regionCounts[$0, default: 0])" }
        .joined(separator: " ")
    let marketSummary = marketCounts
        .sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }
        .prefix(12)
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: " ")

    return "total=\(blueprints.count) regions[\(regionSummary)] markets[\(marketSummary)]"
}
