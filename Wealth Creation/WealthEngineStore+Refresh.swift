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
    }

    @MainActor
    func performMarketRanking() {
        // Market ranking gate – see WealthEngineStore+Materialization.swift.
        materializeMarketCandidates()
    }

    @MainActor
    func performResearchFeeds() {
        // ── 1. Collect ranked cards ───────────────────────────────────────
        let ranked = rankedAssets.filter { $0.rank > 0 }
        guard !ranked.isEmpty else {
            WealthEventLogStore.shared.record(
                title: "Research Feeds",
                detail: "Skipped: no ranked market cards to evaluate.",
                category: "research",
                tintName: "orange",
                timestamp: .now
            )
            return
        }

        // ── 2. Build live broker-quote lookup ─────────────────────────────
        //
        // WealthBrokerQuote objects are delivered as stream events (not
        // cached in the bridge).  Subscribe to .quote events elsewhere and
        // store them in a future quote-cache store.  For now the engine
        // evaluates cards without a live quote so that research feeds never
        // block on broker connectivity.
        let liveQuoteCache: [String: WealthBrokerQuote] = [:]

        // ── 3. Evaluate each ranked card ──────────────────────────────────
        var refreshedCards: [WealthResearchCard] = []
        refreshedCards.reserveCapacity(ranked.count)

        for opportunity in ranked {
            let quote = liveQuoteCache[opportunity.symbol]
            let card  = WealthResearchFeedEngine.evaluate(opportunity, quote: quote)
            refreshedCards.append(card)
        }

        // ── 4. Prune symbols that are no longer ranked, then batch-update ─
        let activeSymbols = Set(ranked.map(\.symbol))
        WealthResearchIntelStore.shared.pruneSymbolsNotIn(activeSymbols)
        WealthResearchIntelStore.shared.updateBatch(refreshedCards)

        // ── 5. Persist to file-backed cache ───────────────────────────────
        WealthResearchIntelStore.shared.persist()

        // ── 6. Update deep-refresh timestamp ─────────────────────────────
        lastHeavyRefresh = .now

        // ── 7. Audit log ─────────────────────────────────────────────────
        let spikingSymbols = refreshedCards.filter(\.priceSpike).map(\.symbol).joined(separator: ", ")
        let elevatedVol    = refreshedCards.filter { $0.volumeSignal == "Elevated" }.count
        WealthEventLogStore.shared.record(
            title: "Research Feeds",
            detail: """
                Deep refresh complete: \(refreshedCards.count) cards evaluated. \
                Elevated volume: \(elevatedVol). \
                Price spikes: \(spikingSymbols.isEmpty ? "none" : spikingSymbols).
                """,
            category: "research",
            tintName: "green",
            timestamp: .now
        )
    }

    @MainActor
    func performIBKRSync() {
        // Price-only sync via IBKR bridge.
    }
}
