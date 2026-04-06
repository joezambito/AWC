import Foundation

// MARK: - WealthDownstreamRebuildOrchestrator
//
// Owns the downstream rebuild pipeline: AI scan → Market ranking.
//
// ── Purpose ───────────────────────────────────────────────────────────────
//
//   After each universe update or stale-cache detection, the downstream
//   pipeline (AI scores + market ranking) must be re-run so that AI Live,
//   Activity, and Order Restriction see current data.
//
//   `WealthDownstreamRebuildOrchestrator` is the single entry-point for
//   triggering that rebuild.  It deduplicates concurrent requests: if a
//   rebuild is already in flight, additional `triggerRebuild(reason:)` calls
//   are silently ignored.
//
// ── Pipeline steps ────────────────────────────────────────────────────────
//
//   1. runAIScan()       — recalculates AI scores for all ranked assets
//   2. runMarketRanking() — re-ranks the universe with fresh scores
//   3. lastRefresh = Date() — stamps the engine so isCacheStale() returns
//                             false until the configured stale window passes
//   4. markDownstreamRebuildComplete() — arms WealthReadyStateGate and
//                                        posts wealthEngineDidBecomeReady
//
// ── lastRefresh stamp ────────────────────────────────────────────────────
//
//   Writing `lastRefresh = Date()` after each rebuild is critical.  Without
//   it, `WealthStaleCacheDetector.isCacheStale()` always returns `true`
//   (lastRefresh is nil) and triggers a new rebuild on every foreground
//   activation, causing the double-scan bug.
//
// ── Deduplication ────────────────────────────────────────────────────────
//
//   `triggerRebuild(reason:)` checks `rebuildTask == nil` before spawning
//   a new Task.  The task clears `rebuildTask` in a `defer` block so the
//   next `triggerRebuild` call after completion is allowed through.
//
//   Callers that need to interrupt a running rebuild should call
//   `cancelRebuild()` first, then `triggerRebuild(reason:)`.
//
// ── Threading ─────────────────────────────────────────────────────────────
//
//   `@MainActor`.  `runAIScan()` and `runMarketRanking()` are `async` and
//   internally dispatch heavy computation to background actors/tasks.
//   The `lastRefresh` stamp and `markDownstreamRebuildComplete()` call hop
//   back to `@MainActor` via `await MainActor.run { ... }`.

@MainActor
final class WealthDownstreamRebuildOrchestrator {

    // MARK: - Shared instance

    static let shared = WealthDownstreamRebuildOrchestrator()
    private init() {}

    // MARK: - Private state

    private var rebuildTask: Task<Void, Never>?

    // MARK: - Public API

    /// Trigger a downstream rebuild if one is not already in flight.
    ///
    /// - Parameter reason: Human-readable description logged to the event
    ///   log.  Helps identify the source of each rebuild in diagnostics.
    func triggerRebuild(reason: String) {
        guard rebuildTask == nil else { return }

        WealthEventLogStore.shared.record(
            title: "Downstream Rebuild",
            detail: "Triggered: \(reason)",
            category: "orchestration",
            tintName: "blue",
            timestamp: .now
        )

        rebuildTask = Task { [weak self] in
            defer { self?.rebuildTask = nil }
            await self?.performDownstreamRebuild()
        }
    }

    /// Cancel any in-flight rebuild.
    ///
    /// The current scan step is interrupted at its next cooperative
    /// cancellation point.  Call before triggering a fresh rebuild
    /// if you need the new rebuild to start immediately.
    func cancelRebuild() {
        rebuildTask?.cancel()
        rebuildTask = nil
    }

    // MARK: - Private pipeline

    private func performDownstreamRebuild() async {
        let engine = WealthEngineStore.shared

        await engine.runAIScan()
        guard !Task.isCancelled else { return }

        await engine.runMarketRanking()
        guard !Task.isCancelled else { return }

        await MainActor.run {
            engine.lastRefresh = Date()
        }

        WealthReadyStateGate.shared.markDownstreamRebuildComplete()

        WealthEventLogStore.shared.record(
            title: "Downstream Rebuild",
            detail: "Completed: AI scan + market ranking. lastRefresh stamped.",
            category: "orchestration",
            tintName: "green",
            timestamp: .now
        )
    }
}
