import Foundation

// MARK: - WealthConfidenceStore
//
// Tracks the engine's overall prediction confidence on a 0–1 scale.
//
// Confidence is derived from three contributing factors:
//   • Data freshness  – how recent the last successful refresh is
//   • Universe depth  – how many ranked assets are available
//   • AI score spread – how well-distributed AI scores are (not all zeros)
//
// Views and the brain layer read `currentConfidence` to decide whether
// to surface AI Live picks or show a "low confidence" indicator.
//
// No existing engine logic, functions, or behaviors are changed.

@MainActor
final class WealthConfidenceStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthConfidenceStore()
    private init() {}

    // MARK: - Thresholds

    /// Refresh age beyond which the freshness factor drops to zero.
    private let stalenessThreshold: TimeInterval = 30 * 60   // 30 min

    /// Minimum ranked-asset count for full universe-depth confidence.
    private let universeDepthTarget: Int = 50

    // MARK: - Published state

    /// Current blended confidence score in the range 0–1.
    ///
    /// A score ≥ 0.6 is considered "confident enough" for AI Live promotion.
    @Published private(set) var currentConfidence: Double = 0.0

    /// Individual factor scores (0–1) for diagnostic display.
    @Published private(set) var freshnessFactor:   Double = 0.0
    @Published private(set) var depthFactor:       Double = 0.0
    @Published private(set) var aiSpreadFactor:    Double = 0.0

    // MARK: - Public API

    /// Recompute all confidence factors using the current engine state.
    ///
    /// Call this at the end of every materialization pass.
    func recompute() {
        let engine = WealthEngineStore.shared

        // Factor 1 — data freshness
        if let last = engine.lastRefresh {
            let age = Date().timeIntervalSince(last)
            freshnessFactor = max(0.0, 1.0 - age / stalenessThreshold)
        } else {
            freshnessFactor = 0.0
        }

        // Factor 2 — universe depth
        let ranked = engine.rankedAssets.filter { $0.rank > 0 }
        depthFactor = min(1.0, Double(ranked.count) / Double(universeDepthTarget))

        // Factor 3 — AI score spread (at least some non-zero scores)
        let scoredCount = ranked.filter { $0.aiScore > 0 }.count
        aiSpreadFactor  = ranked.isEmpty ? 0.0 : min(1.0, Double(scoredCount) / Double(max(1, ranked.count)))

        // Blend: freshness 40%, depth 30%, spread 30%
        currentConfidence = (freshnessFactor * 0.4) + (depthFactor * 0.3) + (aiSpreadFactor * 0.3)

        WealthEventLogStore.shared.record(
            title: "Confidence Store",
            detail: String(
                format: "confidence=%.2f | fresh=%.2f | depth=%.2f | spread=%.2f",
                currentConfidence, freshnessFactor, depthFactor, aiSpreadFactor
            ),
            category: "engine",
            tintName: currentConfidence >= 0.6 ? "green" : "orange",
            timestamp: .now
        )
    }

    /// Reset all factors to zero (e.g. on factory reset or sign-out).
    func reset() {
        currentConfidence = 0.0
        freshnessFactor   = 0.0
        depthFactor       = 0.0
        aiSpreadFactor    = 0.0
    }

    // MARK: - Queries

    /// `true` when the engine has sufficient confidence to promote AI Live picks.
    var isConfident: Bool { currentConfidence >= 0.6 }
}
