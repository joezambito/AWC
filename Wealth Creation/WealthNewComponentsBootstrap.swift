import Foundation

// MARK: - WealthNewComponentsBootstrap
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   The new pipeline components (audit coordinators, cache sanity checker,
//   background-cache helper) are singletons that must be initialized at app
//   launch in order to register their NotificationCenter observers.  Without
//   an explicit activation call, the lazy singletons remain dormant and their
//   observers never fire.
//
// Solution (new code only):
//   `WealthNewComponentsBootstrap.activate()` is a single call that:
//     1. Initialises every new singleton (touching `shared` so `init()` runs).
//     2. Registers a one-time observer for `wealthEngineDidBecomeReady` that
//        runs all audits and persists file-backed downstream state after each
//        successful rebuild.
//
//   The companion extension `WealthEngineStore.bootstrapWithPipeline()` is a
//   drop-in replacement for the existing `bootstrap()` call that adds the
//   activation step without changing `bootstrap()` itself.
//
// Integration:
//   Replace `WealthEngineStore.shared.bootstrap()` in your app/scene delegate
//   with `WealthEngineStore.shared.bootstrapWithPipeline()`.
//   Or call both independently:
//     WealthEngineStore.shared.bootstrap()
//     WealthNewComponentsBootstrap.activate()

// MARK: - Central activation

@MainActor
enum WealthNewComponentsBootstrap {

    // MARK: - Public API

    /// Activate all new pipeline components.
    ///
    /// Safe to call multiple times – subsequent calls are no-ops thanks to
    /// the internal `isActivated` guard.
    ///
    /// Call once at app launch alongside or immediately after
    /// `WealthEngineStore.shared.bootstrap()`.
    static func activate() {
        guard !isActivated else { return }
        isActivated = true

        // Touch singletons so their `init()` runs and their own observers register.
        _ = WealthDownstreamCacheSanity.shared
        _ = WealthMarketExecutionAudit.shared
        _ = WealthAILiveRejectionAudit.shared
        _ = WealthActivityAdmissionAudit.shared
        _ = WealthEngineScanScheduler.shared
        _ = WealthEngineRuntimeCoordinator.shared
        _ = WealthEngineRuntimeRecovery.shared
        _ = WealthAILiveCoordinator.shared
        _ = WealthOrderRestrictionRules.shared
        _ = WealthPortfolioLifecycleHelper.shared

        // Observe `wealthEngineDidBecomeReady` to run audits and persist
        // file-backed downstream state after every successful rebuild.
        NotificationCenter.default.addObserver(
            forName: .wealthEngineDidBecomeReady,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                runPostReadyPipeline()
            }
        }

        WealthEventLogStore.shared.record(
            title: "Pipeline Bootstrap",
            detail: "New pipeline components activated (audits + cache sanity + runtime).",
            category: "orchestration",
            tintName: "blue",
            timestamp: .now
        )
    }

    // MARK: - Private state

    private static var isActivated: Bool = false

    // MARK: - Post-ready pipeline

    /// Called once after each successful downstream rebuild.
    /// Runs all audit reports, evaluates AI Live candidates (with scan-progress
    /// gate), runs order-restriction audit, and persists file-backed caches.
    private static func runPostReadyPipeline() {
        let engine = WealthEngineStore.shared

        // ── Market Execution Audit ─────────────────────────────────────
        // Audits the full universe → green → safeguard → market funnel.
        WealthMarketExecutionAudit.shared.runAudit(on: engine.rankedAssets)

        // ── Persist Market snapshot (file-backed, not UserDefaults) ────
        // Only ranked cards (rank > 0) are the Market candidates.
        let marketCards = engine.rankedAssets.filter { $0.rank > 0 }
        WealthDownstreamCacheSanity.shared.saveMarketSnapshot(marketCards)

        // ── AI Live Evaluation (scan-progress gated) ───────────────────
        // Run the evaluation pass; this also calls the rejection audit
        // internally and saves the AI Live results to file-backed storage.
        WealthAILiveCoordinator.shared.evaluateCandidates()

        // ── AI Live Rejection Audit ────────────────────────────────────
        // Audits market cards for conditions that cause AI Live shrinkage.
        WealthAILiveRejectionAudit.shared.runAudit(on: marketCards)

        // ── Order Restriction Audit ────────────────────────────────────
        // Audits AI Live promoted cards for order-restriction blocking.
        let promotedCards = WealthAILiveCoordinator.shared.promotedCards
        WealthOrderRestrictionRules.shared.runAudit(on: promotedCards)

        // ── Activity Admission Audit ───────────────────────────────────
        // Audits AI Live promoted cards for Activity blocking conditions.
        WealthActivityAdmissionAudit.shared.runAudit(on: promotedCards)

        // ── Persist AI Live results (file-backed) ──────────────────────
        // Already saved inside WealthAILiveCoordinator.evaluateCandidates().
        // Save the Activity state for freshness tracking.
        let admissibleSymbols = promotedCards
            .filter { $0.isMarketExecutableCandidate && $0.aiScore > 0 }
            .map(\.symbol)
        WealthDownstreamCacheSanity.shared.saveActivityState(admissibleSymbols)
    }
}

// MARK: - WealthEngineStore drop-in bootstrap

extension WealthEngineStore {

    /// Drop-in replacement for `bootstrap()` that also activates all new
    /// pipeline components (audit coordinators, cache sanity, background-cache
    /// helpers) without changing the original `bootstrap()` function.
    ///
    /// Usage: replace `WealthEngineStore.shared.bootstrap()` in your app or
    /// scene delegate with `WealthEngineStore.shared.bootstrapWithPipeline()`.
    func bootstrapWithPipeline() {
        // Call the original bootstrap unchanged.
        bootstrap()
        // Activate all new pipeline components.
        WealthNewComponentsBootstrap.activate()
    }
}
