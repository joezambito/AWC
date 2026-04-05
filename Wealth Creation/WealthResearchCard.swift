import Foundation

// MARK: - WealthResearchCard
//
// Immutable value type that bundles all research-feed intel gathered for
// a single ranked Opportunity at a given point in time.
//
// Fields are populated by `WealthResearchFeedEngine.evaluate(_:quote:)` and
// stored in `WealthResearchIntelStore` keyed by `symbol`.
//
// ── What each field represents ────────────────────────────────────────────
//
//   newsScore           – Composite news / signal quality score (0–100).
//                         Blended from AI score and probability.
//
//   socialScore         – Social / market-sentiment proxy (0.0–1.0).
//                         Derived from probability and AI tier when no
//                         dedicated social feed is connected.
//
//   volumeSignal        – Volume characterisation ("Elevated", "Normal",
//                         "Low", "Pending").  Sourced from IBKR broker
//                         quote if available; falls back to "Pending".
//
//   momentumLabel       – Momentum tier ("Strong", "Building", "Moderate",
//                         "Weak").  Based on AI score and current P/L.
//
//   priceSpike          – `true` when the bid/ask spread exceeds 2 % of
//                         the last traded price, indicating intraday
//                         volatility or a potential price spike.
//
//   analystTier         – Analyst-proxy tier label based on AI score.
//                         Maps to: "Strong Buy" ≥80, "Buy" ≥65,
//                         "Hold" ≥50, "Avoid" <50.
//
//   intelligenceDrivers – Short strings naming each active signal driver
//                         (e.g. "Momentum: Strong", "Volume: Elevated").
//
//   intelligenceChannels– Short strings naming each data source that
//                         contributed intel (e.g. "AI Brain",
//                         "IBKR Market Data").
//
//   reviewSummary       – Human-readable narrative summarising the card's
//                         signal profile.  Chosen from a fixed set of
//                         templates that match the templates embedded in
//                         WealthCore.swift.
//
//   refreshedAt         – Timestamp of the last research-feed pass that
//                         populated this card.

struct WealthResearchCard: Codable, Equatable {

    // MARK: Identity

    /// Ticker symbol this intel applies to.
    let symbol: String

    // MARK: - Scoring signals

    /// Composite news-and-signal quality score (0–100).
    /// Blended from `aiScore` (60 %), risk inversion (30 %), and
    /// probability (10 %).
    let newsScore: Int

    /// Social / market-sentiment proxy score (0.0–1.0).
    /// Derived from probability and AI tier when a dedicated social feed
    /// is not yet connected.
    let socialScore: Double

    // MARK: - Market signals

    /// Volume characterisation sourced from the IBKR broker quote.
    /// "Elevated" | "Normal" | "Low" | "Pending" (no live quote yet).
    let volumeSignal: String

    /// Momentum tier based on AI score and current unrealized P/L.
    /// "Strong" | "Building" | "Moderate" | "Weak"
    let momentumLabel: String

    /// `true` when bid/ask spread exceeds 2 % of the last traded price,
    /// indicating an intraday price spike or elevated volatility.
    let priceSpike: Bool

    // MARK: - Analyst proxy

    /// AI-score-based analyst proxy tier.
    /// "Strong Buy" (aiScore ≥ 80) | "Buy" (≥ 65) | "Hold" (≥ 50) | "Avoid"
    let analystTier: String

    // MARK: - Intelligence narrative

    /// Short driver strings displayed on the card detail view.
    /// Example: ["Momentum: Strong", "Volume: Elevated", "Risk: Low"]
    let intelligenceDrivers: [String]

    /// Data-source channel strings displayed on the card detail view.
    /// Example: ["AI Brain", "IBKR Market Data", "Social Feeds"]
    let intelligenceChannels: [String]

    /// Human-readable narrative summary chosen from a fixed template set
    /// that mirrors the templates embedded in WealthCore.swift.
    let reviewSummary: String

    // MARK: - Freshness

    /// Timestamp when this research card was last populated.
    let refreshedAt: Date
}
