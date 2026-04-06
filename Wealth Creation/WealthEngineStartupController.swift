import Foundation

@MainActor
final class WealthEngineStartupController {

    static let shared = WealthEngineStartupController()

    private var startupTask: Task<Void, Never>?
    private(set) var isStartupComplete: Bool = false

    private enum Delay {
        static let afterUniverse: UInt64 = 2_000_000_000  // 2 s
        static let afterAI:       UInt64 = 1_000_000_000  // 1 s
        static let afterMarket:   UInt64 = 1_000_000_000  // 1 s
    }

    private init() {}

    // MARK: - Public API

    func beginStartupSequence() {
        guard startupTask == nil, !isStartupComplete else { return }
        startupTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.runStartupSequence()
        }
    }

    func cancelStartupSequence() {
        startupTask?.cancel()
        startupTask = nil
        isStartupComplete = false
    }

    // MARK: - Startup sequence

    private nonisolated func runStartupSequence() async {
        let engine = WealthEngineStore.shared

        WealthStartupLagTracer.shared.trace("runStartupSequence – start")

        await MainActor.run {
            WealthEngineRuntimeRecovery.shared.runStartupIntegrityCheck()
        }

        WealthEngineScanScheduler.shared.markPhaseComplete(.cacheRestore)

        // ── Step 1: Universe scan ─────────────────────────────────────────
        WealthStartupLagTracer.shared.trace("universeScan – start")

        let hasCachedUniverse = await Task.detached(priority: .userInitiated) {
            WealthMarketUniverseStore.shared.prepareCachedSnapshotForStartup()
        }.value

        if hasCachedUniverse {
            WealthDataAliveStore.shared.recordUniverseDownload()
            WealthEngineScanScheduler.shared.markPhaseComplete(.universeScan)
        } else {
            await Task.detached(priority: .userInitiated) {
                await WealthMarketUniverseStore.shared.reloadForStartupSequence()
            }.value
            WealthDataAliveStore.shared.recordUniverseDownload()
            WealthEngineScanScheduler.shared.markPhaseComplete(.universeScan)
        }

        WealthStartupLagTracer.shared.trace("universeScan – done")

        // Permit IBKR connection now that the universe is loaded.
        await MainActor.run {
            WealthIBKRBridge.shared.permitConnectionAfterStartup()
        }

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterUniverse)
        guard !Task.isCancelled else { return }

        // ── Step 2: AI scan ───────────────────────────────────────────────
        WealthStartupLagTracer.shared.trace("aiScan – start")
        await engine.runAIScanWithProgress()
        WealthStartupLagTracer.shared.trace("aiScan – done")

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterAI)
        guard !Task.isCancelled else { return }

        // ── Step 3: Market ranking ────────────────────────────────────────
        WealthStartupLagTracer.shared.trace("marketRanking – start")
        await engine.runMarketRankingWithProgress()
        WealthStartupLagTracer.shared.trace("marketRanking – done")

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterMarket)
        guard !Task.isCancelled else { return }

        // ── Step 4: Research feeds ────────────────────────────────────────
        WealthStartupLagTracer.shared.trace("researchFeeds – start")
        await engine.runResearchFeedsWithProgress()
        WealthStartupLagTracer.shared.trace("researchFeeds – done")

        guard !Task.isCancelled else { return }

        // ── Done ──────────────────────────────────────────────────────────
        await MainActor.run {
            isStartupComplete = true
            startupTask = nil
            engine.tradingLifecycleArmed = true
            engine.rescheduleTimers()
        }

        WealthStartupLagTracer.shared.trace("rescheduleTimers – done; startup complete")
        WealthStartupLagTracer.shared.printSummary()

        await MainActor.run {
            WealthReadyStateGate.shared.markDownstreamRebuildComplete()
        }

        WealthEventLogStore.shared.record(
            title: "Startup Controller",
            detail: "Startup sequence complete. Timers rescheduled. Ready-state gate armed.",
            category: "orchestration",
            tintName: "green",
            timestamp: .now
        )
    }
}
