import Foundation

// MARK: - WealthEngineStore+Activation
//
// Extends WealthEngineStore with the one-time startup activation sequence.
//
// ── Architecture context ─────────────────────────────────────────────────
//
// There are now TWO entry-points that can trigger the startup pipeline:
//
//   Path A (NEW – preferred):
//     ContentView.onAppear
//       └─ WealthEngineStore.bootstrap()
//            └─ WealthAppSessionController.prepareLaunch()
//                 └─ WealthEngineStartupController.beginStartupSequence()
//                      ├─ runUniverseScanWithProgress()
//                      ├─ runAIScanWithProgress()
//                      ├─ runMarketRankingWithProgress()
//                      └─ runResearchFeedsWithProgress() → rescheduleTimers()
//
//   Path B (LEGACY – kept for backward compatibility):
//     WealthCore.swift → runActivationSequence()  (this file)
//
// ── Known issue: Competing startup paths ─────────────────────────────────
//
//   If BOTH paths fire (e.g. WealthCore.swift calls runActivationSequence()
//   AND ContentView calls bootstrap()), the startup pipeline runs twice:
//   once through Path B's activationTask and once through Path A's
//   startupTask.  This wastes resources and can corrupt state.
//
//   WealthEngineStartupController guards against its own re-entry via
//   `startupTask == nil && !isStartupComplete`.
//   Path B guards against its own re-entry via `activationTask == nil`.
//   But NEITHER guard prevents the OTHER path from running concurrently.
//
//   Ideal fix: remove the WealthCore.swift call to runActivationSequence()
//   and rely exclusively on Path A (WealthAppSessionController).
//
// ── Timer architecture note ───────────────────────────────────────────────
//
//   The current timer architecture (WealthEngineStore+Timers.swift) uses
//   `softTimer` (10 m + 20 m soft refresh) and `heavyTimer` (30 m deep
//   refresh), plus IBKR price timers at 9 m, 19 m, 29 m.
//
//   Older stored properties `scheduledCheckpointTimer` and `preScanBurstTimer`
//   have been removed from WealthEngineStore.  The canonical way to tear
//   down ALL timers is `invalidateTimers()` from WealthEngineStore+Timers.swift.
//
// Fixes:
//   UI Thread Fix – heavy I/O moved off @MainActor to background tasks
//   Timer Bug Fix – manual teardown replaced with canonical invalidateTimers()

extension WealthEngineStore {

    // MARK: - Activation sequence

    /// Begin the one-time startup activation sequence.
    ///
    /// Heavy I/O (universe reload, AI brain scan, market warmup) runs on a
    /// detached background task so the UI stays responsive.  Progress-state
    /// and completion flags are always set on the @MainActor.
    ///
    /// Idempotent: subsequent calls while an activation is already in
    /// progress are no-ops.
    func runActivationSequence() {
        guard activationTask == nil else { return }

        // Tear down any residual timers from a previous session so they
        // cannot fire while the activation sequence is running.
        // Uses the canonical invalidation path from WealthEngineStore+Timers.swift
        // which handles all current timer references (softTimer, heavyTimer,
        // IBKR timers, extra soft timers) without referencing removed properties.
        invalidateTimers()

        downstreamRecoveryPending = true

        activationTask = Task { @MainActor [self] in

            // ── Cleanup on exit (cancellation or completion) ─────────────
            defer {
                if Task.isCancelled {
                    pendingRefreshPayload = nil
                    startupSequencePhase = .idle
                    endDashboardRefreshFreeze()
                }
                activationTask = nil
            }

            // ── Pre-scan delay ────────────────────────────────────────────
            startupSequencePhase = .waitingToScan
            try? await Task.sleep(nanoseconds: phoneStartupScanDelayNanoseconds)
            guard !Task.isCancelled else { return }

            // ── Heavy work on background thread ───────────────────────────
            // Universe reload, AI brain scan, and market warmup are moved
            // off the @MainActor so the UI never freezes during downloads.
            await Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }

                // Attempt to reuse a cached universe snapshot first.
                // If no valid cache exists, perform a full network reload.
                let reusedCachedUniverse =
                    WealthMarketUniverseStore.shared.prepareCachedSnapshotForStartup()
                guard !Task.isCancelled else { return }

                if !reusedCachedUniverse {
                    await WealthMarketUniverseStore.shared.reloadForStartupSequence()
                    guard !Task.isCancelled else { return }
                }

                // AI brain scan (heavy – reads stored brain state + scores all cards)
                await self.runStartupActivationScan()
                guard !Task.isCancelled else { return }

                // Market warmup (materialise ranked candidates, IBKR prices)
                await self.runStartupMarketWarmup()
                guard !Task.isCancelled else { return }

                // ── UI state update on main thread ────────────────────────
                await MainActor.run {
                    self.activationStage = 0
                    self.activationCycleComplete = true
                    self.lockedCheckpointProgress = Self.lockedCheckpointCount
                    self.tradingLifecycleArmed = true
                    self.startupSequencePhase = .idle
                    self.rescheduleTimers()
                }
            }.value
        }
    }
}
