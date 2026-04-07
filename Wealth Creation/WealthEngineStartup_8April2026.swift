// WealthEngineStartup_8April2026.swift
// Wealth Creation — Startup / bootstrap / activation lifecycle (8 April 2026)

import Foundation

extension WealthEngineStore {
    private var phoneStartupScanDelayNanoseconds: UInt64 { 2_000_000_000 }
    private var warmStartRefreshDelayNanoseconds: UInt64 { 3_000_000_000 }
    private var warmStartRefreshWatchdogNanoseconds: UInt64 { 20_000_000_000 }
    private var phoneStartupFinalizeDelayNanoseconds: UInt64 { 2_000_000_000 }
    private var softScanDurationNanoseconds: UInt64 { 4_000_000_000 }
    private var deepScanDurationNanoseconds: UInt64 { 8_000_000_000 }

    var prefersFullSpeedActivation: Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }

    func runActivationSequence() {
        guard activationTask == nil else { return }
        scheduledCheckpointTimer?.invalidate()
        softTimer?.invalidate()
        heavyTimer?.invalidate()
        preScanBurstTimer?.invalidate()
        scheduledCheckpointTimer = nil
        softTimer = nil
        heavyTimer = nil
        preScanBurstTimer = nil
        downstreamRecoveryPending = true

        activationTask = Task { @MainActor [self] in
            defer {
                if Task.isCancelled {
                    pendingRefreshPayload = nil
                    startupSequencePhase = .idle
                    endDashboardRefreshFreeze()
                }
                activationTask = nil
            }

            startupSequencePhase = .waitingToScan
            try? await Task.sleep(nanoseconds: phoneStartupScanDelayNanoseconds)
            guard !Task.isCancelled else { return }

            let reusedCachedUniverse = WealthMarketUniverseStore.shared.prepareCachedSnapshotForStartup()
            guard !Task.isCancelled else { return }

            if !reusedCachedUniverse {
                startupSequencePhase = .universeRefreshRunning
                await WealthMarketUniverseStore.shared.reloadForStartupSequence()
                guard !Task.isCancelled else { return }
            }

            startupSequencePhase = .aiScanRunning
            startScanProgressAnimation(for: .startup)
            await runStartupActivationScan()
            guard !Task.isCancelled else { return }

            await applyPendingRefreshState()
            guard !Task.isCancelled else { return }

            startupSequencePhase = .marketWarmupRunning
            await runStartupMarketWarmup()
            guard !Task.isCancelled else { return }

            activationStage = 0
            activationCycleComplete = true
            lockedCheckpointProgress = Self.lockedCheckpointCount
            tradingLifecycleArmed = true
            await refreshDownstreamPromotionStateAfterStartupGate()
            guard !Task.isCancelled else { return }
            startupSequencePhase = .idle
            rescheduleTimers()
        }
    }

    func prepareForFreshLaunch() {
        scheduledCheckpointTimer?.invalidate()
        softTimer?.invalidate()
        heavyTimer?.invalidate()
        preScanBurstTimer?.invalidate()
        scheduledCheckpointTimer = nil
        softTimer = nil
        heavyTimer = nil
        preScanBurstTimer = nil
        activationTask?.cancel()
        activationTask = nil
        hasBootstrapped = false
        pendingRefreshPayload = nil
        pendingPublishTask?.cancel()
        pendingPublishTask = nil
        scanProgressAnimationTask?.cancel()
        scanProgressAnimationTask = nil
        scanProgressAnimationEndsAt = nil
        activationStageTotal = prefersFullSpeedActivation ? 1 : Self.phoneActivationStageCount
        activationStage = 0
        activationCycleComplete = false
        lockedCheckpointProgress = 0
        tradingLifecycleArmed = false
        downstreamRecoveryPending = false
        startupSequencePhase = .idle
        appOpenUpdatedAt = nil
        invalidatePersistedMarketRestoreGuard()
        endDashboardRefreshFreeze()
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        catchUpRecurringCyclesIfNeeded()

        restorePersistedMarketCacheIfNeeded()
        if useWarmStartupCacheIfAvailable() {
            return
        }

        activationStageTotal = prefersFullSpeedActivation ? 1 : Self.phoneActivationStageCount
        activationStage = 0
        activationCycleComplete = false
        lockedCheckpointProgress = 0
        tradingLifecycleArmed = false
        runActivationSequence()
    }

    func handleForegroundActivation() {
        guard activationTask == nil else { return }
        catchUpRecurringCyclesIfNeeded()
        restorePersistedMarketCacheIfNeeded()
        if useWarmStartupCacheIfAvailable() {
            return
        }
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 8 {
            return
        }

        activationStageTotal = prefersFullSpeedActivation ? 1 : Self.phoneActivationStageCount
        activationStage = 0
        activationCycleComplete = false
        lockedCheckpointProgress = 0
        tradingLifecycleArmed = false
        runActivationSequence()
    }

    @discardableResult
    private func useCachedPhoneStateIfAvailable() -> Bool {
        guard !(scanUniverse.isEmpty && rankedAssets.isEmpty) else { return false }
        activationStageTotal = prefersFullSpeedActivation ? 1 : Self.phoneActivationStageCount
        activationStage = 0
        activationCycleComplete = true
        lockedCheckpointProgress = Self.lockedCheckpointCount
        tradingLifecycleArmed = false
        return true
    }

    @discardableResult
    private func useWarmStartupCacheIfAvailable() -> Bool {
        let restoredUniverse = WealthMarketUniverseStore.shared.prepareCachedSnapshotForStartup()
        let restoredCards = useCachedPhoneStateIfAvailable()

        guard restoredUniverse || restoredCards || hasUsableWarmStartCardCache else { return false }
        guard hasUsableWarmStartCardCache || restoredUniverse else { return false }

        applyWarmStartVisibleState()
        if downstreamRecoveryPending {
            runActivationSequence()
        } else {
            queueSilentWarmStartRefreshIfNeeded()
        }
        return true
    }

    private func queueSilentWarmStartRefreshIfNeeded() {
        guard activationTask == nil else { return }
        guard warmStartRefreshTask == nil else { return }

        let staleInterval = max(60, configuredSoftRefreshMinutes * 60)
        let shouldRefresh = lastRefresh == nil || Date().timeIntervalSince(lastRefresh!) >= staleInterval
        guard shouldRefresh else { return }

        warmStartRefreshTask = Task { [weak self] in
            guard let self else { return }

            let watchdog = Task { [weak self] in
                try? await Task.sleep(nanoseconds: self?.warmStartRefreshWatchdogNanoseconds ?? 20_000_000_000)
                guard let self else { return }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    WealthEventLogStore.shared.record(
                        title: "Warm Refresh Watchdog",
                        detail: "Silent warm-start refresh exceeded the watchdog window and was cancelled to keep cached UI stable.",
                        category: "refresh",
                        tintName: "orange",
                        timestamp: .now
                    )
                    self.warmStartRefreshTask?.cancel()
                }
            }

            defer {
                watchdog.cancel()
                Task { @MainActor [weak self] in
                    self?.warmStartRefreshTask = nil
                }
            }

            try? await Task.sleep(nanoseconds: warmStartRefreshDelayNanoseconds)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.activationTask == nil else { return }
                guard !self.isDashboardRefreshInFlight else { return }
                WealthEventLogStore.shared.record(
                    title: "Warm Refresh",
                    detail: "Cached open is staying visible while a silent background refresh runs.",
                    category: "refresh",
                    tintName: "cyan",
                    timestamp: .now
                )
            }

            await self.refreshAsync(mode: .soft, publishToUI: false)
        }
    }

    func startScanProgressAnimation(for mode: RefreshMode) {
        guard let durationNanoseconds = progressAnimationDurationNanoseconds(for: mode) else { return }
        scanProgressAnimationTask?.cancel()
        scanProgressAnimationTask = nil
        scanProgressAnimationEndsAt = Date().addingTimeInterval(Double(durationNanoseconds) / 1_000_000_000)
        activationStageTotal = Self.lockedCheckpointCount
        activationStage = 0
        activationCycleComplete = false
        lockedCheckpointProgress = 0

        let stepDelayNanoseconds = max(1, durationNanoseconds / UInt64(Self.lockedCheckpointCount))
        scanProgressAnimationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for step in 1...Self.lockedCheckpointCount {
                guard !Task.isCancelled else { return }
                self.activationStage = step
                self.lockedCheckpointProgress = step
                if step < Self.lockedCheckpointCount {
                    try? await Task.sleep(nanoseconds: stepDelayNanoseconds)
                }
            }
        }
    }

    func progressAnimationDurationNanoseconds(for mode: RefreshMode) -> UInt64? {
        switch mode {
        case .soft:
            return softScanDurationNanoseconds
        case .heavy, .deep:
            return deepScanDurationNanoseconds
        case .startup:
            return phoneStartupFinalizeDelayNanoseconds
        case .quick:
            return nil
        }
    }

    func pendingDashboardPublishDelayNanoseconds(now: Date = .now) -> UInt64 {
        let baseDelayNanoseconds: UInt64 = 2_000_000_000
        guard let endsAt = scanProgressAnimationEndsAt else { return baseDelayNanoseconds }
        let remainingSeconds = max(0, endsAt.timeIntervalSince(now))
        let remainingNanoseconds = UInt64(remainingSeconds * 1_000_000_000)
        return baseDelayNanoseconds + remainingNanoseconds
    }

    private func runStartupMarketWarmup() async {
        let portfolio = WealthPortfolioStore.shared
        let universeStore = WealthMarketUniverseStore.shared
        let quoteStore = WealthBrokerQuoteStore.shared
        let snapshotStore = WealthPreparedSnapshotStore.shared

        isMarketMaterializationInFlight = true
        defer { isMarketMaterializationInFlight = false }

        let marketCandidates = WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: lastRefresh)

        snapshotStore.invalidatePreparedMarkets()
        snapshotStore.refreshMarkets(
            engine: self,
            portfolio: portfolio,
            universeStore: universeStore,
            quoteStore: quoteStore
        )
        WealthMarketViewCycleStore.shared.syncCycle(
            candidates: marketCandidates,
            cycleMarker: lastRefresh
        )
        if let pendingMarketMaterializationTask {
            await pendingMarketMaterializationTask.value
        } else {
            await Task.yield()
        }
        snapshotStore.refreshCore(engine: self, portfolio: portfolio)
    }
}
