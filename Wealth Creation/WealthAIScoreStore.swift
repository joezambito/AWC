import Foundation

// MARK: - WealthAIScoreStore
//
// Persists AI scores and confidence values across app sessions so that
// cards retain their score after a restart without waiting for a full
// AI scan to complete.
//
// Scores are keyed by opportunity symbol and stored in UserDefaults.

@MainActor
final class WealthAIScoreStore {

    // MARK: Shared instance

    static let shared = WealthAIScoreStore()
    private init() {
        loadFromDisk()
    }

    // MARK: - UserDefaults keys

    private enum Keys {
        static let scores      = "awc_ai_scores"
        static let confidence  = "awc_ai_confidence"
        static let savedAt     = "awc_ai_scores_saved_at"
    }

    // MARK: - In-memory cache

    private var scores:     [String: Double] = [:]
    private var confidence: [String: Double] = [:]

    /// When the scores were last persisted.
    private(set) var lastSavedAt: Date?

    // MARK: - Public API

    /// Return the cached AI score for a symbol, or `nil` if not stored.
    func score(for symbol: String) -> Double? {
        scores[symbol]
    }

    /// Return the cached confidence for a symbol, or `nil` if not stored.
    func confidence(for symbol: String) -> Double? {
        confidence[symbol]
    }

    /// Persist scores and confidence values from a batch of opportunities.
    func save(_ opportunities: [Opportunity]) {
        for opp in opportunities {
            scores[opp.symbol]     = opp.aiScore
            confidence[opp.symbol] = opp.probability
        }
        lastSavedAt = Date()
        writeToDisk()

        WealthEventLogStore.shared.record(
            title: "AI Score Store",
            detail: "Saved \(opportunities.count) AI scores.",
            category: "brain",
            tintName: "blue",
            timestamp: .now
        )
    }

    /// Remove all cached scores (called on universe rebuild or cache invalidation).
    func invalidate() {
        scores.removeAll()
        confidence.removeAll()
        lastSavedAt = nil
        UserDefaults.standard.removeObject(forKey: Keys.scores)
        UserDefaults.standard.removeObject(forKey: Keys.confidence)
        UserDefaults.standard.removeObject(forKey: Keys.savedAt)
    }

    // MARK: - Persistence

    private func writeToDisk() {
        UserDefaults.standard.set(scores,     forKey: Keys.scores)
        UserDefaults.standard.set(confidence, forKey: Keys.confidence)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.savedAt)
    }

    private func loadFromDisk() {
        scores     = UserDefaults.standard.dictionary(forKey: Keys.scores)     as? [String: Double] ?? [:]
        confidence = UserDefaults.standard.dictionary(forKey: Keys.confidence) as? [String: Double] ?? [:]
        if let ts = UserDefaults.standard.object(forKey: Keys.savedAt) as? Double {
            lastSavedAt = Date(timeIntervalSince1970: ts)
        }
    }
}
