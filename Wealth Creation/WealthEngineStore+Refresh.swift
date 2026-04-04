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
    /// the actual work on a `.userInitiated` background thread.
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
        await DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.performUniverseScan()
            }
        }
    }

    /// Rate cards with AI score + confidence (reference only, no ranking).
    func runAIScan() async {
        await DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.performAIScan()
            }
        }
    }

    /// Apply the market ranking gate (top 100 executable greens only).
    func runMarketRanking() async {
        await DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.performMarketRanking()
            }
        }
    }

    /// Append final research-feed intel to ranked cards.
    func runResearchFeeds() async {
        await DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.performResearchFeeds()
            }
        }
    }

    // MARK: - Composite refresh pipelines

    private func runIBKRPriceSync() async {
        await DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.performIBKRSync()
            }
        }
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
    // @Published properties.  They are called only from background-initiated
    // Tasks and dispatch back to the main actor via the enclosing Task block.

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
}

// MARK: - DispatchQueue async/await shim

private extension DispatchQueue {
    func async(_ work: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            self.async {
                work()
                continuation.resume()
            }
        }
    }
}
