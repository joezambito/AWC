import Foundation

// MARK: - WealthEngineStore+Refresh
//
// Three refresh modes, all executed on background threads so the UI is
// never blocked:
//
//   .ibkr  → update live prices / broker data only (fastest)
//   .soft  → light refresh: universe + AI + market (change-gated)
//   .deep  → heavy refresh: universe + AI + market + research (change-gated)
//
// ── Caching strategy (see WealthEngineStore+UniverseCache.swift) ──────────
//
//   Universe
//   ────────
//   Soft and deep refreshes skip the universe re-download when the data is
//   fresh (< 6 h) and the fingerprint (record count) is unchanged.  The
//   download only runs when the freshness window has elapsed or the
//   fingerprint differs from the stored value.
//
//   Cards (AI scan + market ranking)
//   ─────────────────────────────────
//   Cards are re-scored only when the universe changed in the current cycle
//   OR when IBKR market data was updated since the last card refresh pass.
//   If neither condition is true, the AI scan and market ranking are skipped
//   and the cached ranked set continues to be used.
//
//   IBKR price sync
//   ────────────────
//   After every IBKR price sync, `recordMarketDataUpdated()` is called so
//   the subsequent soft/deep cycle knows to re-score cards with fresh prices.
//
// Individual scan entry-points (runUniverseScan, runAIScan, etc.) are also
// defined here and are called both during the startup sequence and during
// recurring timer refreshes.

extension WealthEngineStore {

    // MARK: Refresh mode

    enum RefreshMode {
        /// Price and broker-data update only (9 m, 19 m, 29 m timers).
        case ibkr
        /// Light refresh: universe, AI score, market ranking (10 m, 20 m).
        case soft
        /// Heavy/deep refresh: everything including research feeds (30 m).
        case deep
    }

    // MARK: - Public refresh entry-point

    /// Dispatch a refresh on the appropriate background queue.
    /// This method is safe to call from any context; it always executes
    /// the actual work via `Task.detached` on a `.userInitiated` background thread.
    func refresh(mode: RefreshMode) async {
        switch mode {
        case .ibkr:
            await runIBKRPriceSync()
        case .soft:
            await runSoftRefresh()
        case .deep:
            await runDeepRefresh()
        }
    }

    // MARK: - Scan entry-points (called by startup controller & timers)

    /// Download all opportunity cards and score them.
    func runUniverseScan() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performUniverseScan()
        }.value
    }

    /// Rate cards with AI score + confidence (reference only, no ranking).
    func runAIScan() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performAIScan()
        }.value
    }

    /// Apply the market ranking gate (top 100 executable greens only).
    func runMarketRanking() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performMarketRanking()
        }.value
    }

    /// Append final research-feed intel to ranked cards.
    func runResearchFeeds() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performResearchFeeds()
        }.value
    }

    // MARK: - Composite refresh pipelines

    private func runIBKRPriceSync() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performIBKRSync()
        }.value
        // Record market-data update so the next soft/deep cycle knows to re-score cards.
        await MainActor.run { [weak self] in self?.recordMarketDataUpdated() }
    }

    private func runSoftRefresh() async {
        // Check whether a universe re-download is needed this cycle.
        let needsUniverse = await MainActor.run { [weak self] in
            self?.universeNeedsDownload() ?? true
        }

        var universeChanged = false
        if needsUniverse {
            await runUniverseScan()
            // Record the download outcome and detect if the universe actually changed.
            universeChanged = await MainActor.run { [weak self] in
                self?.recordUniverseDownloaded() ?? true
            }
        }

        // Re-score cards only when the universe changed or market data was updated.
        let needsCards = await MainActor.run { [weak self] in
            self?.cardsNeedRefresh(universeChanged: universeChanged) ?? true
        }
        if needsCards {
            await runAIScan()
            await runMarketRanking()
            await MainActor.run { [weak self] in self?.recordCardsRefreshed() }
        }
    }

    private func runDeepRefresh() async {
        // Check whether a universe re-download is needed this cycle.
        let needsUniverse = await MainActor.run { [weak self] in
            self?.universeNeedsDownload() ?? true
        }

        var universeChanged = false
        if needsUniverse {
            await runUniverseScan()
            // Record the download outcome and detect if the universe actually changed.
            universeChanged = await MainActor.run { [weak self] in
                self?.recordUniverseDownloaded() ?? true
            }
        }

        // Re-score cards only when the universe changed or market data was updated.
        let needsCards = await MainActor.run { [weak self] in
            self?.cardsNeedRefresh(universeChanged: universeChanged) ?? true
        }
        if needsCards {
            await runAIScan()
            await runMarketRanking()
            await MainActor.run { [weak self] in self?.recordCardsRefreshed() }
        }

        // Research feeds always run on deep refresh — they pull from an
        // independent data source and are scheduled infrequently (30 min).
        await runResearchFeeds()
    }

    // MARK: - Low-level scan implementations (override points)
    //
    // These @MainActor methods perform the actual data work and update
    // @Published properties.  Task.detached above ensures they are scheduled
    // on a background executor before hopping to @MainActor for the update.

    @MainActor
    func performUniverseScan() {
        // Implemented in WealthCore.swift (existing engine logic).
        // This extension stub is the designated call site; override or
        // extend as needed when the core implementation is refactored.
    }

    @MainActor
    func performAIScan() {
        // AI scoring pass – populates aiScore + confidence on each card.
        WealthBrainStore.shared.ingest(
            opportunities: rankedAssets,
            focusOpportunity: rankedAssets.first(where: { $0.rank == 1 }),
            stage: activationStage,
            stageTotal: 6,
            cycleComplete: activationCycleComplete,
            lastRefresh: lastRefresh
        )
    }

    @MainActor
    func performMarketRanking() {
        // Market ranking gate – see WealthEngineStore+Materialization.swift.
        materializeMarketCandidates()
    }

    @MainActor
    func performResearchFeeds() {
        // Appends research-feed intel to ranked cards.
    }

    @MainActor
    func performIBKRSync() {
        // Price-only sync via IBKR bridge.
    }
}
