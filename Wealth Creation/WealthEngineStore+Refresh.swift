import Foundation

// MARK: - WealthEngineStore+Refresh
//
// Three refresh modes dispatched by recurring timers and the startup sequence:
//
//   .ibkr  → IBKR price sync only
//   .soft  → universe (cache-gated) + AI + market
//   .deep  → universe (cache-gated) + AI + market + research
//
// Universe cache gate (root-cause fix):
//   runUniverseScan() checks WealthDataAliveStore.isUniverseAlive before
//   calling performUniverseScan().  isUniverseAlive reads from UserDefaults
//   (key "awc_universe_last_downloaded") so the guard survives app restarts.
//   The universe is downloaded only when genuinely stale (> 6 h old).
//   After a real download, recordUniverseDownload() stamps UserDefaults so
//   every subsequent call within the 6 h window is a skip.

extension WealthEngineStore {

    // MARK: - Refresh mode

    enum RefreshMode {
        case ibkr   // price sync only
        case soft   // universe (gated) + AI + market
        case deep   // universe (gated) + AI + market + research
    }

    // MARK: - Public refresh entry-point

    func refresh(mode: RefreshMode) async {
        switch mode {
        case .ibkr: await runIBKRPriceSync()
        case .soft: await runSoftRefresh()
        case .deep: await runDeepRefresh()
        }
    }

    // MARK: - Scan entry-points

    func runUniverseScan() async {
        guard !WealthDataAliveStore.shared.isUniverseAlive else {
            WealthEventLogStore.shared.record(
                title: "Universe Scan",
                detail: "Skipped – universe is fresh (< 6 h). No download.",
                category: "cache",
                tintName: "blue",
                timestamp: .now
            )
            return
        }
        performUniverseScan()
        WealthDataAliveStore.shared.recordUniverseDownload()
    }

    func runAIScan() async {
        performAIScan()
    }

    func runMarketRanking() async {
        performMarketRanking()
    }

    func runResearchFeeds() async {
        performResearchFeeds()
    }

    // MARK: - Composite pipelines

    private func runIBKRPriceSync() async {
        performIBKRSync()
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

    // MARK: - Override points for WealthCore.swift

    @MainActor func performUniverseScan() {}

    @MainActor
    func performAIScan() {
        WealthBrainStore.shared.ingest(
            opportunities: rankedAssets,
            focusOpportunity: rankedAssets.first(where: { $0.rank == 1 }),
            stage: activationStage,
            stageTotal: 6,
            cycleComplete: activationCycleComplete,
            lastRefresh: lastRefresh
        )
    }

    @MainActor func performMarketRanking() { materializeMarketCandidates() }
    @MainActor func performResearchFeeds() {}
    @MainActor func performIBKRSync()      {}
}
