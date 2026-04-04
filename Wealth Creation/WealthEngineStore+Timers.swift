import Foundation

// MARK: - WealthEngineStore+Timers
//
// Manages the single recurring checkpoint timer that drives all post-startup
// refresh cycles.
//
// ── Timer design ─────────────────────────────────────────────────────────
//
//   A single `scheduledCheckpointTimer` fires every 10 minutes.
//   `lockedCheckpointProgress` counts fires within the current 30-minute
//   cycle (0 → lockedCheckpointCount).
//
//   Fire 1 (10 min) – soft  refresh: universe, AI score, market ranking
//   Fire 2 (20 min) – soft  refresh: universe, AI score, market ranking
//   Fire 3 (30 min) – deep  refresh: everything (includes research feeds)
//                     → resets lockedCheckpointProgress to 0
//
// All callbacks dispatch to a background Task so @MainActor / UI is never
// blocked.  Only ONE timer reference (`scheduledCheckpointTimer`) is ever
// stored; there is no softTimer, heavyTimer, or preScanBurstTimer.

extension WealthEngineStore {

    // MARK: - Checkpoint interval

    /// Interval between consecutive checkpoint-timer fires (seconds).
    private var checkpointInterval: TimeInterval { 10 * 60 }   // 10 min

    // MARK: - Public API

    /// Tear down any existing checkpoint timer and schedule a fresh one.
    ///
    /// Called automatically by `WealthEngineStartupController` once the
    /// startup sequence completes, and again whenever the app is
    /// foregrounded after a prolonged background period.
    ///
    /// Idempotent: safe to call multiple times.
    func rescheduleTimers() {
        invalidateTimers()
        scheduleCheckpointTimer()
    }

    /// Invalidate and release the checkpoint timer.
    ///
    /// Called by `resetToFactoryDefaults()` and before any re-schedule.
    func invalidateTimers() {
        scheduledCheckpointTimer?.invalidate()
        scheduledCheckpointTimer = nil
    }

    // MARK: - Private scheduling

    private func scheduleCheckpointTimer() {
        scheduledCheckpointTimer = Timer.scheduledTimer(
            withTimeInterval: checkpointInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.handleCheckpointFire()
            }
        }
    }

    // MARK: - Checkpoint handler

    /// Executed on a background thread each time `scheduledCheckpointTimer`
    /// fires.  Determines whether to run a soft or deep refresh based on
    /// `lockedCheckpointProgress`, then updates the progress counter.
    private func handleCheckpointFire() async {
        // Determine refresh depth and advance the checkpoint counter.
        let mode: RefreshMode = await MainActor.run {
            lockedCheckpointProgress += 1

            if lockedCheckpointProgress >= Self.lockedCheckpointCount {
                lockedCheckpointProgress = 0
                return RefreshMode.deep
            }
            return RefreshMode.soft
        }

        guard !Task.isCancelled else { return }
        await refresh(mode: mode)
    }
}
