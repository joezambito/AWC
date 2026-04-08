import Foundation

extension WealthEngineStore {
    private func normalizeScanRefreshSettingsIfNeeded() {
        normalizeRefreshValue(
            key: StorageKey.lightRefreshMinutes,
            legacyDefault: Self.legacySoftRefreshMinutes,
            fallback: Self.defaultSoftRefreshMinutes,
            minimum: Self.minimumSoftRefreshMinutes
        )
        normalizeRefreshValue(
            key: StorageKey.heavyRefreshMinutes,
            legacyDefault: Self.legacyHeavyRefreshMinutes,
            fallback: Self.defaultHeavyRefreshMinutes,
            minimum: Self.minimumHeavyRefreshMinutes
        )
    }

    private func normalizeRefreshValue(
        key: String,
        legacyDefault: Double,
        fallback: Double,
        minimum: Double
    ) {
        guard let saved = defaults.object(forKey: key) as? Double else {
            defaults.set(fallback, forKey: key)
            return
        }

        if saved == legacyDefault || saved < minimum {
            defaults.set(fallback, forKey: key)
        }
    }

    private func normalizePersistedMarketCacheDecisionStatesIfNeeded() {
        guard
            let data = Self.loadPersistedRankedAssetsData(from: defaults),
            let payload = try? JSONDecoder().decode([WealthPortfolioStore.PersistedOpportunity].self, from: data),
            payload.contains(where: { $0.decisionBiasRaw == WealthDecisionBias.hold.rawValue })
        else {
            return
        }

        let normalized = payload.map(WealthPortfolioStore.normalizedPersistedOpportunity)
        guard let encoded = try? JSONEncoder().encode(normalized) else { return }
        Self.persistRankedAssetsData(encoded)
        defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
    }

    private func restorePersistedMarketCache() {
        cacheRestoreUpdatedAt = .now
        marketMaterializationUpdatedAt = .distantPast
        var restoredCachedData = false
        var normalizedScanUniverseFromCache = false
        let hasUsableFullUniverseSnapshot = WealthMarketUniverseStartupCache.hasUsableFullSnapshot()

        let rankedDecoder = JSONDecoder()
        rankedDecoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )

        if let data = Self.loadPersistedRankedAssetsData(from: defaults),
           let payload = try? rankedDecoder.decode([WealthPortfolioStore.PersistedOpportunity].self, from: data) {
            rankedAssets = payload.map(WealthPortfolioStore.restorePersistedOpportunity(from:))
            restoredCachedData = !payload.isEmpty
        }

        if hasUsableFullUniverseSnapshot,
           let data = Self.loadPersistedScanUniverseData(from: defaults),
           let payload = try? rankedDecoder.decode([WealthPortfolioStore.PersistedOpportunity].self, from: data) {
            scanUniverse = payload
                .map(WealthPortfolioStore.restorePersistedOpportunity(from:))
                .map(WealthAllCardsStore.normalizePermissionForColorRule)
            normalizedScanUniverseFromCache = !payload.isEmpty
            restoredCachedData = restoredCachedData || !payload.isEmpty
        }

        if !hasUsableFullUniverseSnapshot {
            defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
            if let cacheURL = Self.scanUniverseFileURL() {
                try? FileManager.default.removeItem(at: cacheURL)
            }
        }

        let aiLiveDecoder = JSONDecoder()
        aiLiveDecoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )

        if let data = defaults.data(forKey: StorageKey.cachedAILiveResults),
           let payload = try? aiLiveDecoder.decode([WealthAILiveResult].self, from: data) {
            aiLiveResultsByKey = payload.reduce(into: [String: WealthAILiveResult]()) { partialResult, item in
                partialResult[item.key] = item
            }
        }

        lastRefresh = defaults.object(forKey: StorageKey.cachedLastRefresh) as? Date
        lastHeavyRefresh = defaults.object(forKey: StorageKey.cachedLastHeavyRefresh) as? Date
        isUsingCachedMarketData = restoredCachedData

        let refreshTime = lastRefresh
        let portfolio = WealthPortfolioStore.shared
        let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let cachedUniverse = rankedAssets.isEmpty ? scanUniverse : rankedAssets
        if !shouldTrustCachedLivePromotionState() {
            aiLiveResultsByKey = [:]
        }
        let livePickKeys = WealthAllCardsStore.visibleLivePickKeys(
            from: cachedUniverse,
            aiLiveResults: aiLiveResultsByKey,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: portfolio.freeBuyingPower
        )
        WealthAllCardsStore.shared.sync(
            opportunities: cachedUniverse,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys,
            refreshTime: refreshTime
        )
        downstreamRecoveryPending = requiresDownstreamLiveRecovery()

        if normalizedScanUniverseFromCache {
            persistMarketCache()
        }
    }

    func persistMarketCache() {
        persistMarketCacheSnapshot(
            rankedAssets: rankedAssets,
            scanUniverse: scanUniverse,
            aiLiveResultsByKey: aiLiveResultsByKey,
            lastRefresh: lastRefresh,
            lastHeavyRefresh: lastHeavyRefresh
        )
    }

    func persistMarketCacheSnapshot(
        rankedAssets: [Opportunity],
        scanUniverse: [Opportunity],
        aiLiveResultsByKey: [String: WealthAILiveResult],
        lastRefresh: Date?,
        lastHeavyRefresh: Date?
    ) {
        let rankedPayload = rankedAssets.map(WealthPortfolioStore.persistedOpportunity(from:))
        let scanPayload = scanUniverse.map(WealthPortfolioStore.persistedOpportunity(from:))
        let rankedEncoder = JSONEncoder()
        rankedEncoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        if let data = try? rankedEncoder.encode(rankedPayload) {
            Self.persistRankedAssetsData(data)
            defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
        }
        if let data = try? rankedEncoder.encode(scanPayload) {
            Self.persistScanUniverseData(data)
            defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
        }

        let aiLivePayload = Array(aiLiveResultsByKey.values)
        let aiLiveEncoder = JSONEncoder()
        aiLiveEncoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        if let data = try? aiLiveEncoder.encode(aiLivePayload) {
            defaults.set(data, forKey: StorageKey.cachedAILiveResults)
        }

        defaults.set(lastRefresh, forKey: StorageKey.cachedLastRefresh)
        defaults.set(lastHeavyRefresh, forKey: StorageKey.cachedLastHeavyRefresh)
        defaults.synchronize()
    }

    func resetCachedRuntimeStateToZero() {
        softTimer?.invalidate()
        heavyTimer?.invalidate()
        softTimer = nil
        heavyTimer = nil
        activationTask?.cancel()
        activationTask = nil
        warmStartRefreshTask?.cancel()
        warmStartRefreshTask = nil
        pendingMarketMaterializationTask?.cancel()
        pendingMarketMaterializationTask = nil
        isMarketMaterializationInFlight = false

        rankedAssets = []
        scanUniverse = []
        scannedSignals = []
        lastRefresh = nil
        lastHeavyRefresh = nil
        startupSequencePhase = .idle
        startupSequenceUpdatedAt = .distantPast
        brainSnapshot = .placeholder
        activationStage = 0
        activationCycleComplete = false
        lockedCheckpointProgress = 0
        tradingLifecycleArmed = false
        downstreamRecoveryPending = false
        lastDecisionSummary = "AI online"
        dashboardSnapshot = nil
        appOpenUpdatedAt = nil
        cacheRestoreUpdatedAt = nil
        isDashboardRefreshInFlight = false
        dashboardRefreshUpdatedAt = .distantPast
        isUsingCachedMarketData = false
        aiLiveResultsByKey = [:]
        activityRefusalsByKey = [:]
        marketMaterializationUpdatedAt = .distantPast

        stagedDashboardSnapshot = nil
        frozenRankedAssets = []
        frozenScannedSignals = []
        frozenConfirmedHoldings = []
        frozenPendingHoldings = []
        frozenPendingOpportunities = []
        frozenCompletedOpportunities = []

        defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
        defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
        defaults.removeObject(forKey: StorageKey.cachedAILiveResults)
        defaults.removeObject(forKey: StorageKey.cachedLastRefresh)
        defaults.removeObject(forKey: StorageKey.cachedLastHeavyRefresh)
        if let cacheURL = Self.rankedAssetsFileURL() {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        if let cacheURL = Self.scanUniverseFileURL() {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        didRestorePersistedMarketCache = false

        WealthBrainStore.shared.resetToPlaceholder()
    }

    func applySharedVisibleSnapshot(
        _ sharedCards: [Opportunity],
        refreshTime: Date?,
        heavyRefreshTime: Date?
    ) {
        let portfolio = WealthPortfolioStore.shared
        let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let livePickKeys = WealthAllCardsStore.visibleLivePickKeys(
            from: sharedCards,
            aiLiveResults: aiLiveResultsByKey,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: portfolio.freeBuyingPower
        )

        scanUniverse = sharedCards
        rankedAssets = sharedCards
        lastRefresh = refreshTime
        lastHeavyRefresh = heavyRefreshTime
        isUsingCachedMarketData = !sharedCards.isEmpty

        WealthDataAliveStore.shared.sync(cards: sharedCards, refreshTime: refreshTime)
        WealthAIScoreStore.shared.sync(cards: sharedCards, refreshTime: refreshTime)
        WealthConfidenceStore.shared.sync(cards: sharedCards, refreshTime: refreshTime)
        WealthAllCardsStore.shared.sync(
            opportunities: sharedCards,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys,
            refreshTime: refreshTime
        )
        persistMarketCache()
        restoreDashboardSnapshotFromCurrentStores()
    }

    private static func loadPersistedScanUniverseData(from defaults: UserDefaults) -> Data? {
        if let fileURL = scanUniverseFileURL(),
           let fileData = try? Data(contentsOf: fileURL) {
            return fileData
        }

        guard let stored = defaults.data(forKey: StorageKey.cachedScanUniverse) else {
            return nil
        }

        persistScanUniverseData(stored)
        defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
        return stored
    }

    private static func loadPersistedRankedAssetsData(from defaults: UserDefaults) -> Data? {
        if let fileURL = rankedAssetsFileURL(),
           let fileData = try? Data(contentsOf: fileURL) {
            defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
            return fileData
        }

        guard let stored = defaults.data(forKey: StorageKey.cachedRankedAssets) else {
            return nil
        }

        persistRankedAssetsData(stored)
        defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
        return stored
    }

    private static func persistRankedAssetsData(_ data: Data) {
        guard let fileURL = rankedAssetsFileURL() else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func persistScanUniverseData(_ data: Data) {
        guard let fileURL = scanUniverseFileURL() else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func rankedAssetsFileURL() -> URL? {
        guard let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return baseURL
            .appendingPathComponent("WealthCreationCache", isDirectory: true)
            .appendingPathComponent(CacheConstants.rankedAssetsFileName)
    }

    private static func scanUniverseFileURL() -> URL? {
        guard let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return baseURL
            .appendingPathComponent("WealthCreationCache", isDirectory: true)
            .appendingPathComponent(CacheConstants.scanUniverseFileName)
    }
}
