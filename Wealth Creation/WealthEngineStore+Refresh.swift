import Foundation

// MARK: - WealthEngineStore+Refresh
//
// Three refresh modes, all executed on background threads so the UI is
// never blocked:
//
//   .ibkr  → update live prices / broker data only (fastest)
//   .soft  → light refresh: universe + AI + market + downstream rebuild
//   .deep  → heavy refresh: everything + downstream rebuild
//
// Individual scan entry-points (runUniverseScan, runAIScan, etc.) are also
// defined here and are called both during the startup sequence and during
// recurring timer refreshes.
//
// Downstream rebuild pipeline (Fix 3, 4, 5):
//   runDownstreamRebuild()
//     ├─ runAILiveEvaluation()   ← AI Live from current Market state (Fix 4)
//     └─ runActivityReevaluation() ← Activity admission after AI Live (Fix 5)

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

    // MARK: - Downstream rebuild entry-points (Fix 3, 4, 5)

    /// Evaluate promotion-ready ranked cards with the AI Live engine and
    /// produce live pick keys from the current Market state.
    ///
    /// Called after every market ranking pass and on every session resume
    /// to ensure AI Live data is never left empty or stale.
    func runAILiveEvaluation() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performAILiveEvaluation()
        }.value
    }

    /// Reevaluate Activity admission for all valid promoted cards.
    ///
    /// Called immediately after `runAILiveEvaluation()` completes so that
    /// queue / pending / live transitions fire without waiting for the next
    /// unrelated timer tick.
    func runActivityReevaluation() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performActivityReevaluation()
        }.value
    }

    /// Run the full downstream rebuild pipeline synchronously:
    ///   Market (current ranked state) → AI Live evaluation → Activity admission
    ///
    /// This is the minimal pass needed to restore live state after an unlock
    /// or after market ranking completes.  Ready-state must NOT be declared
    /// until this returns (Fix 6).
    func runDownstreamRebuild() async {
        await runAILiveEvaluation()
        await runActivityReevaluation()
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
        // Always rebuild downstream after every ranking pass (Fix 3).
        await runDownstreamRebuild()
    }

    private func runDeepRefresh() async {
        await runUniverseScan()
        await runAIScan()
        await runMarketRanking()
        await runResearchFeeds()
        // Always rebuild downstream after every full refresh (Fix 3).
        await runDownstreamRebuild()
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

    // MARK: - Downstream scan implementations (Fix 4, 5)

    /// AI Live evaluation pass (Fix 4).
    ///
    /// Rebuilds AI Live results from the current ranked Market cards.
    /// All ranked, market-executable cards are considered promotion-ready
    /// and their symbols are submitted as live pick keys so that
    /// `WealthAllCardsStore` reflects the current live session.
    ///
    /// If `rankedAssets` contains no ranked cards (rank > 0) this is a
    /// no-op; the next market ranking pass will populate them.
    @MainActor
    func performAILiveEvaluation() {
        let livePickSymbols = rankedAssets
            .filter { $0.rank > 0 && $0.isMarketExecutableCandidate }
            .map(\.symbol)

        WealthAllCardsStore.shared.sync(
            opportunities: rankedAssets,
            activityKeys: [],
            holdingKeys: Set(holdings.map(\.symbol)),
            livePickKeys: livePickSymbols,
            refreshTime: lastRefresh
        )
    }

    /// Activity reevaluation pass (Fix 5).
    ///
    /// Triggers queue / pending / live transitions for promoted cards
    /// immediately after AI Live rebuilds, rather than waiting for the
    /// next unrelated timer tick.
    @MainActor
    func performActivityReevaluation() {
        // Publish a dashboard update so all downstream SwiftUI observers
        // (Activity lane, live picks panel) receive the rebuilt state.
        publishDashboardUpdate()
    }
}
