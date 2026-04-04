import Foundation

// MARK: - WealthEngineStartupController
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
        static let afterUniverse: UInt64 = 1_000_000_000  // 1 s  (was 2 s)
        static let afterAI:       UInt64 =   500_000_000  // 0.5 s (was 1 s)
        static let afterMarket:   UInt64 =   500_000_000  // 0.5 s (was 1 s)
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

        // ── Pre-flight: integrity check ───────────────────────────────────
        // Reset any stuck in-flight state from a previous interrupted session
        // before starting a new run.
        WealthEngineRuntimeRecovery.shared.runStartupIntegrityCheck()

        // Mark cache restore complete (restoreCacheInBackground was already
        // called before beginStartupSequence; record it in the scheduler).
        WealthEngineScanScheduler.shared.markPhaseComplete(.cacheRestore)

        // ── Step 1 : Universe scan ────────────────────────────────────────
        await engine.runUniverseScanWithProgress()

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterUniverse)
        guard !Task.isCancelled else { return }

        // ── Step 2 : AI scan ─────────────────────────────────────────────
        await engine.runAIScanWithProgress()

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterAI)
        guard !Task.isCancelled else { return }

        // ── Step 3 : Market ranking ───────────────────────────────────────
        await engine.runMarketRankingWithProgress()

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterMarket)
        guard !Task.isCancelled else { return }

        // ── Step 4 : Research feeds ───────────────────────────────────────
        await engine.runResearchFeedsWithProgress()

        guard !Task.isCancelled else { return }

        // ── Done : start recurring timers ─────────────────────────────────
        isStartupComplete = true
        startupTask = nil
        engine.rescheduleTimers()

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
