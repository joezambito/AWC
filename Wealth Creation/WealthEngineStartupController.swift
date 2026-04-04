import Foundation

// MARK: - WealthEngineStartupController
//
// Orchestrates the one-time startup sequence on first app launch AND the
// downstream rebuild on subsequent unlock/reopen events.
//
// First-launch sequence (beginStartupSequence):
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
//            Downstream rebuild: AI Live eval → Activity admission
//               ↓
//            Start recurring timers (9m/10m/19m/20m/29m/30m)
//
// Unlock/reopen sequence (resumeSession):
//   Unlock → Stale-cache check
//          → Downstream rebuild: Market (cached) → AI Live eval → Activity
//          → Reschedule timers

@MainActor
final class WealthEngineStartupController {

    // MARK: Shared instance

    static let shared = WealthEngineStartupController()

    // MARK: Private state

    private var startupTask: Task<Void, Never>?
    private var sessionResumeTask: Task<Void, Never>?

    // MARK: Public state

    /// Set to `true` only after the first full startup sequence completes.
    private(set) var isStartupComplete: Bool = false

    /// Set to `true` only after a downstream rebuild (AI Live → Activity)
    /// has completed in the current session.  Reset on sign-out / factory
    /// reset, and also reset each time a new session resume starts.
    /// Use this to gate "ready" state — the UI should not consider data
    /// fresh until this is `true`.
    private(set) var isDownstreamRebuildComplete: Bool = false

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

    /// Resume the live session after an unlock or foreground event.
    ///
    /// Unlike `beginStartupSequence()`, this method is NOT gated by
    /// `isStartupComplete`, so it always runs on every unlock/reopen.
    /// It runs only the downstream rebuild (Market cached → AI Live → Activity)
    /// which is the minimal work needed to restore fresh live state.
    ///
    /// Safe to call multiple times – any in-flight resume is cancelled and
    /// restarted so the latest Market state is always used.
    func resumeSession() {
        sessionResumeTask?.cancel()
        isDownstreamRebuildComplete = false

        sessionResumeTask = Task { [weak self] in
            await self?.runSessionResumeSequence()
        }
    }

    /// Cancel any in-flight startup or session resume (e.g. on sign-out /
    /// factory reset).
    func cancelStartupSequence() {
        startupTask?.cancel()
        startupTask = nil
        isStartupComplete = false

        sessionResumeTask?.cancel()
        sessionResumeTask = nil
        isDownstreamRebuildComplete = false
    }

    // MARK: - Private startup sequence

    private func runStartupSequence() async {
        let engine = WealthEngineStore.shared

        // ── Step 1 : Universe scan ────────────────────────────────────────
        await engine.runUniverseScan()

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterUniverse)
        guard !Task.isCancelled else { return }

        // ── Step 2 : AI scan ─────────────────────────────────────────────
        await engine.runAIScan()

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterAI)
        guard !Task.isCancelled else { return }

        // ── Step 3 : Market ranking ───────────────────────────────────────
        await engine.runMarketRanking()

        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: Delay.afterMarket)
        guard !Task.isCancelled else { return }

        // ── Step 4 : Research feeds ───────────────────────────────────────
        await engine.runResearchFeeds()

        guard !Task.isCancelled else { return }

        // ── Step 5 : Downstream rebuild (AI Live → Activity) ─────────────
        // Must complete before ready-state is declared (Fix 6).
        await engine.runDownstreamRebuild()

        guard !Task.isCancelled else { return }

        // ── Done : start recurring timers ─────────────────────────────────
        isStartupComplete = true
        isDownstreamRebuildComplete = true
        startupTask = nil
        engine.rescheduleTimers()
    }

    // MARK: - Private session resume sequence

    /// Minimal rebuild path for unlock / foreground events.
    /// Assumes Market data is already cached; only rebuilds the downstream
    /// pipeline so AI Live and Activity reflect the current Market state.
    private func runSessionResumeSequence() async {
        let engine = WealthEngineStore.shared

        // ── Downstream rebuild: Market (cached) → AI Live → Activity ─────
        await engine.runDownstreamRebuild()

        guard !Task.isCancelled else { return }

        isDownstreamRebuildComplete = true
        sessionResumeTask = nil
        engine.rescheduleTimers()
    }
}
