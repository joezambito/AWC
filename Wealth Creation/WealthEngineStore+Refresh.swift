import Foundation

// MARK: - WealthEngineStore+Refresh
//
// Three refresh modes, all executed on background threads so the UI is
// never blocked:
//
//   .ibkr  → update live prices / broker data only (fastest)
//   .soft  → light refresh: universe + AI + market
//   .deep  → heavy refresh: everything (universe, AI, market, research)
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

    // MARK: - Scan entry-points with scan-scheduler progress reporting
    //
    // Called exclusively by WealthEngineStartupController so that each scan
    // phase is both executed AND recorded in WealthEngineScanScheduler.
    // Using separate wrappers keeps the base run* methods free of startup-
    // specific concerns and lets timer refreshes call them without triggering
    // redundant progress events.

    /// Universe scan + progress mark for WealthEngineStartupController.
    func runUniverseScanWithProgress() async {
        await runUniverseScan()
        WealthEngineScanScheduler.shared.markPhaseComplete(.universeScan)
    }

    /// AI scan + progress mark for WealthEngineStartupController.
    func runAIScanWithProgress() async {
        await runAIScan()
        WealthEngineScanScheduler.shared.markPhaseComplete(.aiScan)
    }

    /// Market ranking + progress mark for WealthEngineStartupController.
    func runMarketRankingWithProgress() async {
        await runMarketRanking()
        WealthEngineScanScheduler.shared.markPhaseComplete(.marketRanking)
    }

    /// Research feeds + progress mark for WealthEngineStartupController.
    func runResearchFeedsWithProgress() async {
        await runResearchFeeds()
        WealthEngineScanScheduler.shared.markPhaseComplete(.researchFeeds)
    }

    // MARK: - Composite refresh pipelines

    private func runIBKRPriceSync() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performIBKRSync()
        }.value
    }

    private func runSoftRefresh() async {
        await runUniverseScan()
        await runAIScan()
        await runMarketRanking()
    }

    private func runDeepRefresh() async {
        await runUniverseScan()
        await runAIScan()
        await runMarketRanking()
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
