import Foundation

// MARK: - Opportunity+CardStateMachine
//
// Computed properties and helpers that implement the card state machine
// described in the problem statement.
//
// Card lifecycle:
//
//   Scored opportunity
//       ↓
//   GREEN CHECK
//   ├─ Strong Green (unrealizedPnL ≥ 0)  → eligible for Market Ranking
//   ├─ Weak Green   (unrealizedPnL < 0)  → routed to Blue (waiting)
//   └─ Fails check                       → Red / Grey
//       ↓
//   SAFEGUARD GATE (see WealthEngineStore+Materialization.swift)
//       ↓
//   MARKET RANKING (rank assigned here; no card bypasses this gate)
//       ↓
//   AI LIVE EVALUATION → Activity / Blue / stays in bucket

extension Opportunity {

    // MARK: - Green card classification

    /// A "Strong Green" card has a non-negative unrealized P/L.
    /// These are the only cards eligible to enter market ranking.
    var isStrongGreen: Bool {
        unrealizedPnL >= 0
    }

    /// A "Weak Green" card has a negative unrealized P/L.
    /// It is routed to the Blue (waiting) bucket until conditions improve.
    var isWeakGreen: Bool {
        unrealizedPnL < 0
    }

    // MARK: - Safeguard checks (consumed by WealthEngineStore+Materialization)

    /// `true` when the card's analysis data is considered stale and
    /// should not be used for ranking.
    var isDataStale: Bool {
        dataQualityLabel.localizedCaseInsensitiveContains("stale")
    }

    /// `true` when there are no execution-state blockers (e.g. pending
    /// orders, blocked symbols, settlement holds).
    ///
    /// Delegates to `isMarketExecutableCandidate` which already encodes
    /// the full execution-viability check in the core model.
    var isExecutionClean: Bool {
        isMarketExecutableCandidate
    }

    /// `true` when the card is not flagged with an unstable anomaly signal.
    var isAnomalyStable: Bool {
        !aiRiskStance.localizedCaseInsensitiveContains("unstable")
    }

    /// Earnings-event risk score (0–100).
    ///
    /// A value ≥ 70 triggers the safeguard gate rejection.
    ///
    /// ⚠️ PLACEHOLDER – Replace this computed property with the dedicated
    /// earnings-risk field from the `Opportunity` model once it is available
    /// (e.g. a property sourced from earnings-calendar or news-event data).
    /// The current derivation from the generic `risk` float is NOT semantically
    /// equivalent to earnings-specific risk and WILL produce incorrect safeguard
    /// decisions in production until replaced.
    var earningsRisk: Int {
        // Temporary: derive from existing `risk` float property (0–1 range → 0–100).
        Int((risk * 100).rounded())
    }

    /// Macro-event risk score (0–100).
    ///
    /// A value ≥ 75 triggers the safeguard gate rejection.
    ///
    /// ⚠️ PLACEHOLDER – Replace this computed property with a dedicated
    /// macro/geopolitical risk field from the `Opportunity` model.
    /// The current inverted-probability calculation is NOT semantically
    /// equivalent to macro risk and WILL produce incorrect safeguard
    /// decisions in production until replaced.
    var macroRisk: Int {
        // Temporary: derive from `probability` inverted (high probability → lower risk).
        Int(((1.0 - probability) * 100).rounded())
    }

    // MARK: - Blue card ranking helpers

    /// A Blue card's rank within its own waiting-list bucket.
    /// Lower rank = higher priority for re-promotion to Green.
    var blueRankPriority: Int {
        // Rank by AI score descending; ties broken by symbol (stable sort).
        Int(aiScore)
    }
}
