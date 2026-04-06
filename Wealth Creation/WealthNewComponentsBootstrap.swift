import Foundation

@MainActor
enum WealthNewComponentsBootstrap {

    // MARK: - Public API

    static func activate() {
        guard !isActivated else { return }
        isActivated = true

        // Register the post-ready pipeline observer FIRST so it fires before
        // WealthDownstreamCacheSanity.validatePersistedDownstreamState().
        // This ensures caches are written before freshness validation runs.
        NotificationCenter.default.addObserver(
            forName: .wealthEngineDidBecomeReady,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                runPostReadyPipeline()
            }
        }

        // Touch singletons so their init() runs and observers register.
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
        _ = WealthBrainStore.shared

        WealthEventLogStore.shared.record(
            title: "Pipeline Bootstrap",
            detail: "New pipeline components activated.",
            category: "orchestration",
            tintName: "blue",
            timestamp: .now
        )
    }

    // MARK: - Private state

    private static var isActivated: Bool = false

    // MARK: - Post-ready pipeline

    private static func runPostReadyPipeline() {
        let engine = WealthEngineStore.shared

        WealthMarketExecutionAudit.shared.runAudit(on: engine.rankedAssets)

        let marketCards = engine.rankedAssets.filter { $0.rank > 0 }
        WealthDownstreamCacheSanity.shared.saveMarketSnapshot(marketCards)

        WealthAILiveCoordinator.shared.evaluateCandidates()

        WealthAILiveRejectionAudit.shared.runAudit(on: marketCards)

        let promotedCards = WealthAILiveCoordinator.shared.promotedCards
        WealthOrderRestrictionRules.shared.runAudit(on: promotedCards)
        WealthActivityAdmissionAudit.shared.runAudit(on: promotedCards)

        let admissibleSymbols = promotedCards
            .filter { $0.isMarketExecutableCandidate }
            .map(\.symbol)
        WealthDownstreamCacheSanity.shared.saveActivityState(admissibleSymbols)
    }
}

// MARK: - WealthEngineStore drop-in bootstrap

extension WealthEngineStore {

    func bootstrapWithPipeline() {
        bootstrap()
        WealthNewComponentsBootstrap.activate()
    }
}
