import Foundation

// MARK: - WealthEngineStore+Activation
//
// Replaces the original synchronous `runActivationSequence()` stub in
// WealthCore.swift with a version that moves all heavy I/O off the main
// thread.
//
// Problem addressed:
//   The original implementation ran `WealthMarketUniverseStore.reloadForStartupSequence()`,
//   `runStartupActivationScan()`, and `runStartupMarketWarmup()` synchronously
//   on the @MainActor.  Downloading 128 k universe rows + AI brain scan +
//   market data blocks every UI interaction (scrolling, tab navigation) for
//   up to 5 minutes on app launch.
//
// Solution (threading-only change – NO logic removed):
//   The heavy download/processing steps are wrapped in
//   `Task.detached(priority: .userInitiated)` so they execute on a
//   background executor.  All @Published property assignments that drive
//   the UI hop back to the @MainActor via `MainActor.run { }` only when
//   the background work is complete.
//
//   Pre-flight timer teardown, the startup-delay sleep, cancellation guards,
//   and the defer cleanup block are all preserved exactly as before.

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
        // Also guard against the new startup controller path: if
        // beginStartupSequence() has already completed, yield to it so
        // both orchestrators cannot run the full pipeline concurrently.
        guard activationTask == nil,
              !WealthEngineStartupController.shared.isStartupComplete else { return }

        // Tear down any residual timers from a previous session so they
        // cannot fire while the activation sequence is running.
        scheduledCheckpointTimer?.invalidate()
        softTimer?.invalidate()
        heavyTimer?.invalidate()
        preScanBurstTimer?.invalidate()
        scheduledCheckpointTimer = nil
        softTimer = nil
        heavyTimer = nil
        preScanBurstTimer = nil

        downstreamRecoveryPending = true

        activationTask = Task { @MainActor [self] in

            // ── Cleanup on exit (cancellation or completion) ─────────────
            defer {
                if Task.isCancelled {
                    pendingRefreshPayload = nil
                    startupSequencePhase = .idle
                }
                // Always clear the dashboard-refresh flag so the UI spinner
                // is never stuck — regardless of whether the task completed
                // normally or was cancelled.
                endDashboardRefreshFreeze()
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
