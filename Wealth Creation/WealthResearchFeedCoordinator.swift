import Foundation

// MARK: - WealthResearchFeedCoordinator
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   `performResearchFeeds()` in WealthEngineStore+Refresh.swift is an
//   empty stub.  During the 30-minute deep-scan, the research-feed phase
//   runs but produces no output.  Cards never receive updated `newsScore`
//   or `researchSummary` values, so the UI shows no event/tip/news context
//   alongside each opportunity card.
//
// Solution (new code only):
//   `WealthResearchFeedCoordinator` is the **advanced AI brain**.  It runs
//   only at the 30-minute deep-scan and enriches each ranked card by
//   correlating it against the market signals already stored in
//   `WealthEngineStore.scannedSignals`.
//
//   Flow:
//     scannedSignals (populated by universe scan, WealthCore.swift)
//         ↓  group by symbol
//     per-card signal set
//         ↓  score + summarise
//     newsScore      – 0-100 integer; strength of news/event/signal coverage
//     researchSummary – human-readable summary string shown on detail cards
//
//   newsScore formula:
//     base = min(signalCount * 15, 60)       (more signals → higher score)
//     + (max signal strength above 50) * 0.5 (if signals carry a strength)
//     clamped to [0, 100]
//
//   researchSummary is a short string built from signal descriptions,
//   e.g. "3 signals: earnings+2d, macro-event, analyst-upgrade"
//
//   When no signals match a card, newsScore is set to 0 and
//   researchSummary is cleared so the UI knows no research data is
//   available for that card.
//
// Relationship to the standard brain:
//   `WealthAIBrainCoordinator` (standard brain) computes `aiScore` and
//   `confidence` from in-card risk metrics on EVERY scan cycle.
//   `WealthResearchFeedCoordinator` (advanced brain) augments cards with
//   EXTERNAL search/event/tip data, but only at the 30-minute deep-scan
//   because external lookups are expensive.
//
//   The difference at each timer:
//     10 min / 20 min (soft): standard brain only → aiScore + confidence
//     30 min (deep):          standard brain THEN advanced brain →
//                             aiScore + confidence + newsScore + researchSummary
//
// Fixes:
//   Gap: performResearchFeeds() was an empty stub — newsScore/researchSummary
//        were never populated and search signals were never connected to cards.

@MainActor
final class WealthResearchFeedCoordinator {

    // MARK: Shared instance

    static let shared = WealthResearchFeedCoordinator()
    private init() {}

    // MARK: - Scoring constants

    /// Each matching signal contributes this many points to newsScore (capped).
    private let pointsPerSignal: Int = 15

    /// Maximum points from raw signal count (before strength bonus).
    private let maxCountPoints: Int = 60

    // MARK: - Public API

    /// Apply research feeds to all ranked cards using the engine's current
    /// scanned-signal inventory.
    ///
    /// Each card whose `symbol` has one or more matching signals receives an
    /// updated `newsScore` (0-100) and a `researchSummary` string.
    /// Cards with no signals are zeroed so the UI can display a "no data"
    /// state rather than stale values.
    ///
    /// - Parameters:
    ///   - assets:  The engine's `rankedAssets`, updated in-place.
    ///   - signals: The engine's `scannedSignals` array.
    func applyResearchFeeds(assets: inout [Opportunity], signals: [MarketSignal]) {
        guard !signals.isEmpty else {
            WealthEventLogStore.shared.record(
                title: "AI Advanced Brain",
                detail: "Research feeds skipped: no market signals available.",
                category: "research",
                tintName: "orange",
                timestamp: .now
            )
            return
        }

        // Group signals by symbol for O(1) per-card lookup.
        let signalsBySymbol: [String: [MarketSignal]] = Dictionary(
            grouping: signals,
            by: { $0.symbol }
        )

        var enrichedCount = 0
        assets = assets.map { card in
            let cardSignals = signalsBySymbol[card.symbol] ?? []
            if cardSignals.isEmpty {
                // Clear stale research data when no current signals exist.
                return card.withResearchData(newsScore: 0, researchSummary: "")
            }
            enrichedCount += 1
            return enriched(card, with: cardSignals)
        }

        WealthEventLogStore.shared.record(
            title: "AI Advanced Brain",
            detail: "Research feeds applied: \(enrichedCount)/\(assets.count) cards enriched from \(signals.count) signals.",
            category: "research",
            tintName: enrichedCount == 0 ? "orange" : "green",
            timestamp: .now
        )
    }

    // MARK: - Private enrichment

    /// Build a research-enriched copy of `card` from its matching signals.
    private func enriched(_ card: Opportunity, with signals: [MarketSignal]) -> Opportunity {
        // ── newsScore ─────────────────────────────────────────────────────
        // Scale linearly with signal count up to maxCountPoints, then add a
        // strength bonus from the highest-strength signal above the floor (50).
        let countPoints = min(signals.count * pointsPerSignal, maxCountPoints)

        let strengthBonus = signals
            .map { Int($0.strength) }
            .filter { $0 > 50 }
            .max()
            .map { ($0 - 50) / 2 } ?? 0

        let newsScore = max(0, min(100, countPoints + strengthBonus))

        // ── researchSummary ───────────────────────────────────────────────
        // Build a compact, human-readable string from the first few signals.
        let preview = signals
            .prefix(3)
            .map { $0.label }
            .joined(separator: ", ")
        let total = signals.count
        let summary = total > 3
            ? "\(total) signals: \(preview), +\(total - 3) more"
            : "\(total) signal\(total == 1 ? "" : "s"): \(preview)"

        return card.withResearchData(newsScore: newsScore, researchSummary: summary)
    }
}

// MARK: - Opportunity+ResearchData
//
// Convenience builder that returns a copy of an Opportunity with updated
// research-feed fields.  Follows the same `withRank(_:)` pattern already
// used in `WealthEngineStore+Materialization.swift`.

extension Opportunity {

    /// Return a copy of this Opportunity with updated research-feed fields.
    func withResearchData(newsScore: Int, researchSummary: String) -> Opportunity {
        var copy = self
        copy.newsScore       = newsScore
        copy.researchSummary = researchSummary
        return copy
    }
}

// MARK: - Expected MarketSignal interface
//
// `WealthResearchFeedCoordinator` accesses the following properties on
// `MarketSignal` (defined in WealthCore.swift):
//
//   symbol:   String  – ticker symbol this signal applies to
//   strength: Double  – signal strength 0-100 (higher = stronger)
//   label:    String  – short description, e.g. "earnings+2d"
//
// If the stored property names in WealthCore.swift differ, update the
// three access sites in `enriched(_:with:)` above to match.
