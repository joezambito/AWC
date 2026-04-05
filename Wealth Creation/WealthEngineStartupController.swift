import Foundation

// MARK: - WealthEngineStartupController
//
// REPLACEMENT FILE — Startup Audit & Lag Tracing added.
//
// Tracing additions (observe only – no logic change):
//   `WealthStartupLagTracer.shared.trace(_:)` calls inserted before and after
//   each startup phase so the console and in-app event log show exactly which
//   subsystems fire and how long each phase takes.  A full summary is printed
//   to the console when startup completes.
//   No existing logic, branch, or return path has been altered.
//
// Original documentation preserved below.
//
// Orchestrates the one-time startup sequence on first app launch.
// Replaces the previous parallel "fire everything at once" approach in
// WealthEngineStore.bootstrap() with a staggered background sequence:
//
//   App Launch → Cache restore (fast, UI visible)
//               ↓
//            Universe scan (background)
//               ↓  wait 2 s
//            AI scan (background)
//               ↓  wait 1 s
//            Market ranking (background)
//               ↓  wait 1 s
//            Research feeds (background)
//               ↓
//            Start recurring timers (9m/10m/19m/20m/29m/30m)

@MainActor
final class WealthEngineStartupController {

    // MARK: Shared instance

    static let shared = WealthEngineStartupController()

    // MARK: Private state

    private var startupTask: Task<Void, Never>?
    private(set) var isStartupComplete: Bool = false

    // MARK: Timing constants (seconds)

    private enum Delay {
        static let afterUniverse: UInt64 = 2_000_000_000  // 2 s
        static let afterAI:       UInt64 = 1_000_000_000  // 1 s
        static let afterMarket:   UInt64 = 1_000_000_000  // 1 s
    }

    // MARK: Lifecycle

    private init() {}

    // MARK: - Public API

    /// Begin the staggered startup sequence.
    /// Safe to call multiple times – subsequent calls are no-ops while a
    /// startup is already in progress or has already completed.
    func beginStartupSequence() {
        guard startupTask == nil, !isStartupComplete else { return }

        startupTask = Task { [weak self] in
            await self?.runStartupSequence()
        }
    }

    /// Cancel any in-flight startup (e.g. on sign-out / factory reset).
    func cancelStartupSequence() {
        startupTask?.cancel()
        startupTask = nil
        isStartupComplete = false
    }

    // MARK: - Private startup sequence

    private func runStartupSequence() async {
        let engine = WealthEngineStore.shared

        // ── Startup trace ─────────────────────────────────────────────────
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("runStartupSequence – start")
        }

        // ── Pre-flight: integrity check ───────────────────────────────────
        // Reset any stuck in-flight state from a previous interrupted session
        // before starting a new run.
        WealthEngineRuntimeRecovery.shared.runStartupIntegrityCheck()

        // Mark cache restore complete (restoreCacheInBackground was already
        // called before beginStartupSequence; record it in the scheduler).
        WealthEngineScanScheduler.shared.markPhaseComplete(.cacheRestore)

        // ── Step 1 : Universe scan ────────────────────────────────────────
        // Check for a valid cached universe snapshot before triggering a
        // full network download.  The same prepareCachedSnapshotForStartup()
        // pattern is used here as in WealthEngineStore+Activation.swift so
        // the behaviour is consistent across both startup paths.
        //
        // prepareCachedSnapshotForStartup() returns true when a fresh,
        // valid universe snapshot is already loaded into WealthMarketUniverseStore
        // and can be reused without re-downloading.  If it returns false the
        // full universe scan runs as before (root-cause fix for Issue 4).
        //
        // The call is wrapped in Task.detached to mirror the existing usage
        // in WealthEngineStore+Activation.swift and keep any I/O off the
        // main thread.
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("universeScan – start")
        }
        let hasCachedUniverse = await Task.detached(priority: .userInitiated) {
            WealthMarketUniverseStore.shared.prepareCachedSnapshotForStartup()
        }.value

        if hasCachedUniverse {
            // Valid cache – mark the scan phase complete without re-downloading.
            WealthEngineScanScheduler.shared.markPhaseComplete(.universeScan)
        } else {
            await engine.runUniverseScanWithProgress()
        }
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("universeScan – done")
        }

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterUniverse)
        guard !Task.isCancelled else { return }

        // ── Step 2 : AI scan ─────────────────────────────────────────────
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("aiScan – start")
        }
        await engine.runAIScanWithProgress()
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("aiScan – done")
        }

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterAI)
        guard !Task.isCancelled else { return }

        // ── Step 3 : Market ranking ───────────────────────────────────────
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("marketRanking – start")
        }
        await engine.runMarketRankingWithProgress()
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("marketRanking – done")
        }

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterMarket)
        guard !Task.isCancelled else { return }

        // ── Step 4 : Research feeds ───────────────────────────────────────
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("researchFeeds – start")
        }
        await engine.runResearchFeedsWithProgress()
        await MainActor.run {
            WealthStartupLagTracer.shared.trace("researchFeeds – done")
        }

        guard !Task.isCancelled else { return }

        // ── Done : start recurring timers ─────────────────────────────────
        isStartupComplete = true
        startupTask = nil
        engine.rescheduleTimers()

        // ── Startup trace : final summary ──────────────────────────────────
        WealthStartupLagTracer.shared.trace("rescheduleTimers – done; startup complete")
        WealthStartupLagTracer.shared.printSummary()

        // Signal that startup is complete so the ready-state gate can be
        // armed by the first downstream rebuild (triggered via the
        // wealthEngineDidBecomeReady notification path).
        WealthEventLogStore.shared.record(
            title: "Startup Controller",
            detail: "Startup sequence complete. Timers rescheduled.",
            category: "orchestration",
            tintName: "green",
            timestamp: .now
        )
    }
}
