import Foundation

extension Opportunity {

    // MARK: - Green card classification

    var isStrongGreen: Bool {
        unrealizedPnL >= 0
    }

    var isWeakGreen: Bool {
        unrealizedPnL < 0
    }

    // MARK: - Safeguard checks

    var isDataStale: Bool {
        dataQualityLabel.localizedCaseInsensitiveContains("stale")
    }

    var isExecutionClean: Bool {
        isMarketExecutableCandidate
    }

    var isAnomalyStable: Bool {
        !aiRiskStance.localizedCaseInsensitiveContains("unstable")
    }

    /// Earnings-event risk score (0–100). A value ≥ SafeguardThreshold.earningsRisk
    /// triggers the safeguard gate rejection.
    var earningsRisk: Int {
        Int((risk * 100).rounded())
    }

    /// Macro-event risk score (0–100). A value ≥ SafeguardThreshold.macroRisk
    /// triggers the safeguard gate rejection.
    var macroRisk: Int {
        Int(((1.0 - probability) * 100).rounded())
    }

    // MARK: - Blue card ranking

    /// A Blue card's rank within its own waiting-list bucket.
    /// Lower rank = higher priority for re-promotion to Green.
    var blueRankPriority: Int {
        Int(aiScore)
    }
}
