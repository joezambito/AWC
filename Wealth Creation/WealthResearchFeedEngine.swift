import Foundation

// MARK: - WealthResearchFeedEngine
//
// Pure, stateless scoring engine that derives research-feed intel from
// the observable properties of a ranked `Opportunity` card plus an
// optional live IBKR broker quote.
//
// ── Data sources ─────────────────────────────────────────────────────────
//
//   1. Opportunity model properties
//      • aiScore        (0–100)   – AI conviction score
//      • risk           (0.0–1.0) – generic risk magnitude
//      • probability    (0.0–1.0) – probability of success
//      • unrealizedPnL  (Double)  – current unrealized profit / loss
//      • earningsRisk   (0–100)   – computed earnings-event risk proxy
//      • macroRisk      (0–100)   – computed macro-event risk proxy
//      • isDataStale    (Bool)    – data freshness flag
//      • isAnomalyStable (Bool)   – anomaly-signal stability flag
//      • symbol         (String)  – ticker symbol (for channel labels)
//
//   2. WealthBrokerQuote (IBKR live quote, optional)
//      • bid, ask, last (Double)  – current bid / ask / last price
//      • volume         (Int)     – intraday traded volume
//
// ── Thresholds ────────────────────────────────────────────────────────────
//
//   Volume:    Elevated > 500 000 shares | Low < 100 000 shares
//   PriceSpike: |bid – ask| / last > 2 %
//   Analyst:   aiScore ≥ 80 → "Strong Buy"  | ≥ 65 → "Buy"
//                            | ≥ 50 → "Hold" | < 50  → "Avoid"

struct WealthResearchFeedEngine {

    // MARK: - Volume thresholds

    private enum VolumeThreshold {
        static let elevated: Int = 500_000
        static let low:      Int = 100_000
    }

    // MARK: - Price-spike threshold

    /// Bid/ask spread fraction above which a price spike is flagged.
    private static let priceSpikeSpreadThreshold: Double = 0.02   // 2 %

    // MARK: - Public entry-point

    /// Evaluate a ranked `Opportunity` and an optional live IBKR broker
    /// quote to produce a fully-populated `WealthResearchCard`.
    ///
    /// - Parameters:
    ///   - opportunity: A market-ranked card (rank > 0).
    ///   - quote:       The most recent IBKR broker quote for the symbol,
    ///                  or `nil` if no live quote is available.
    /// - Returns: A `WealthResearchCard` containing all gathered intel.
    static func evaluate(
        _ opportunity: Opportunity,
        quote: WealthBrokerQuote?
    ) -> WealthResearchCard {

        // ── Individual signal derivations ─────────────────────────────

        let newsScore         = computeNewsScore(opportunity)
        let socialScore       = computeSocialScore(opportunity)
        let volumeSignal      = computeVolumeSignal(quote: quote)
        let momentumLabel     = computeMomentumLabel(opportunity)
        let priceSpike        = computePriceSpike(quote: quote)
        let analystTier       = computeAnalystTier(opportunity)
        let drivers           = buildIntelligenceDrivers(
                                    opportunity,
                                    momentumLabel: momentumLabel,
                                    volumeSignal: volumeSignal,
                                    socialScore: socialScore,
                                    quoteAvailable: quote != nil
                                )
        let channels          = buildIntelligenceChannels(
                                    quoteAvailable: quote != nil
                                )
        let reviewSummary     = buildReviewSummary(opportunity)

        return WealthResearchCard(
            symbol:                opportunity.symbol,
            newsScore:             newsScore,
            socialScore:           socialScore,
            volumeSignal:          volumeSignal,
            momentumLabel:         momentumLabel,
            priceSpike:            priceSpike,
            analystTier:           analystTier,
            intelligenceDrivers:   drivers,
            intelligenceChannels:  channels,
            reviewSummary:         reviewSummary,
            refreshedAt:           .now
        )
    }

    // MARK: - newsScore (0–100)

    /// Composite news / signal quality score.
    ///
    /// Blend:
    ///   aiScore × 0.60   (AI conviction weight)
    ///   risk-inversion × 30   (lower risk → higher quality)
    ///   probability × 10      (higher probability of success → higher score)
    private static func computeNewsScore(_ o: Opportunity) -> Int {
        let aiWeight          = Double(o.aiScore) * 0.60
        let riskInversion     = (1.0 - o.risk) * 30.0
        let probabilityBonus  = o.probability * 10.0
        let raw               = aiWeight + riskInversion + probabilityBonus
        return min(100, max(0, Int(raw.rounded())))
    }

    // MARK: - socialScore (0.0–1.0)

    /// Social / market-sentiment proxy score.
    ///
    /// Uses probability and AI tier as a proxy for social sentiment when
    /// a dedicated social-feed integration is not yet available.
    ///
    /// Tiers:
    ///   aiScore ≥ 75 AND probability ≥ 0.70 → 0.80–1.00 (bullish)
    ///   aiScore ≥ 55 AND probability ≥ 0.50 → 0.50–0.79 (neutral-bullish)
    ///   otherwise                            → 0.00–0.49 (neutral/bearish)
    private static func computeSocialScore(_ o: Opportunity) -> Double {
        if o.aiScore >= 75 && o.probability >= 0.70 {
            // Bullish zone: blend both signals then clamp to 0.80–1.00.
            // blend is in ~0.75–1.00 range; we simply clamp to [0.80, 1.00].
            let blend = (Double(o.aiScore) / 100.0 * 0.70) + (o.probability * 0.30)
            return min(1.0, max(0.80, blend))
        } else if o.aiScore >= 55 && o.probability >= 0.50 {
            // Neutral-bullish zone: 0.50–0.79.
            let blend = (Double(o.aiScore) / 100.0 * 0.60) + (o.probability * 0.40)
            return min(0.79, max(0.50, blend))
        } else {
            // Neutral to bearish: 0.00–0.49.
            let blend = (Double(o.aiScore) / 100.0 * 0.50) + (o.probability * 0.50)
            return min(0.49, max(0.0, blend))
        }
    }

    // MARK: - volumeSignal

    /// Volume characterisation derived from the IBKR broker quote.
    ///
    ///   quote == nil           → "Pending"
    ///   volume ≥ 500 000       → "Elevated"
    ///   volume ≥ 100 000       → "Normal"
    ///   volume  < 100 000      → "Low"
    private static func computeVolumeSignal(quote: WealthBrokerQuote?) -> String {
        guard let quote else { return "Pending" }
        switch quote.volume {
        case VolumeThreshold.elevated...: return "Elevated"
        case VolumeThreshold.low..<VolumeThreshold.elevated: return "Normal"
        default: return "Low"
        }
    }

    // MARK: - momentumLabel

    /// Momentum tier derived from AI score and unrealized P/L.
    ///
    ///   aiScore ≥ 80 AND P/L ≥ 0  → "Strong"
    ///   aiScore ≥ 65               → "Building"
    ///   aiScore ≥ 50               → "Moderate"
    ///   aiScore  < 50              → "Weak"
    private static func computeMomentumLabel(_ o: Opportunity) -> String {
        if o.aiScore >= 80 && o.unrealizedPnL >= 0 { return "Strong" }
        if o.aiScore >= 65                          { return "Building" }
        if o.aiScore >= 50                          { return "Moderate" }
        return "Weak"
    }

    // MARK: - priceSpike

    /// `true` when bid/ask spread > 2 % of last traded price.
    private static func computePriceSpike(quote: WealthBrokerQuote?) -> Bool {
        guard let quote, quote.last > 0 else { return false }
        let spread          = abs(quote.ask - quote.bid)
        let spreadFraction  = spread / quote.last
        return spreadFraction > priceSpikeSpreadThreshold
    }

    // MARK: - analystTier

    /// Analyst-proxy tier label derived from AI score.
    ///
    ///   aiScore ≥ 80  → "Strong Buy"
    ///   aiScore ≥ 65  → "Buy"
    ///   aiScore ≥ 50  → "Hold"
    ///   aiScore  < 50 → "Avoid"
    private static func computeAnalystTier(_ o: Opportunity) -> String {
        switch o.aiScore {
        case 80...: return "Strong Buy"
        case 65..<80: return "Buy"
        case 50..<65: return "Hold"
        default: return "Avoid"
        }
    }

    // MARK: - intelligenceDrivers

    /// Build the list of active intelligence driver labels.
    ///
    /// Always included:
    ///   "AI Conviction: [score]/100"
    ///   "Momentum: [label]"
    ///   "Social Sentiment: [Bullish/Neutral/Bearish]"
    ///   "Risk Profile: [Low/Moderate/High]"
    ///   "Earnings Risk: [score]%"
    ///   "Macro Risk: [score]%"
    ///
    /// Conditionally included:
    ///   "Volume: [signal]" – only when a live IBKR quote is available
    private static func buildIntelligenceDrivers(
        _ o: Opportunity,
        momentumLabel: String,
        volumeSignal: String,
        socialScore: Double,
        quoteAvailable: Bool
    ) -> [String] {

        let sentimentLabel: String
        switch socialScore {
        case 0.70...: sentimentLabel = "Bullish"
        case 0.40..<0.70: sentimentLabel = "Neutral"
        default: sentimentLabel = "Bearish"
        }

        let riskLabel: String
        switch o.risk {
        case 0.66...: riskLabel = "High"
        case 0.33..<0.66: riskLabel = "Moderate"
        default: riskLabel = "Low"
        }

        var drivers: [String] = [
            "AI Conviction: \(o.aiScore)/100",
            "Momentum: \(momentumLabel)",
            "Social Sentiment: \(sentimentLabel)",
            "Risk Profile: \(riskLabel)",
            "Earnings Risk: \(o.earningsRisk)%",
            "Macro Risk: \(o.macroRisk)%"
        ]

        if quoteAvailable {
            drivers.append("Volume: \(volumeSignal)")
        }

        return drivers
    }

    // MARK: - intelligenceChannels

    /// Build the list of intelligence data-source channel labels.
    ///
    /// Always present: "AI Brain", "Volume Analysis", "Social Feeds", "Risk Engine".
    /// These represent analytical components that are always evaluated, even when
    /// the underlying signals are derived from AI scores rather than live data.
    /// "IBKR Market Data" is inserted after "AI Brain" only when a live broker
    /// quote was used during this evaluation pass.
    private static func buildIntelligenceChannels(quoteAvailable: Bool) -> [String] {
        var channels = ["AI Brain", "Volume Analysis", "Social Feeds", "Risk Engine"]
        if quoteAvailable {
            channels.insert("IBKR Market Data", at: 1)
        }
        return channels
    }

    // MARK: - reviewSummary

    /// Select the narrative review-summary template that best matches the
    /// card's signal profile.
    ///
    /// Templates are identical to those embedded in WealthCore.swift so that
    /// the review text is consistent regardless of which code path produced it.
    private static func buildReviewSummary(_ o: Opportunity) -> String {
        if o.isDataStale || !o.isAnomalyStable {
            return "No extra intel"
        }
        if o.aiScore >= 80 && o.unrealizedPnL >= 0 {
            return "High-conviction setup backed by momentum, flow, and healthy net profit potential after costs."
        }
        if o.aiScore >= 65 {
            return "Signals are mixed, but sentiment and catalysts keep it inside the active watch bucket."
        }
        if o.aiScore >= 50 {
            return "The macro backdrop keeps the trend interesting, but the volatility profile lowers priority."
        }
        if o.aiScore >= 40 {
            return "AI is monitoring this because it still has trend support, though risk is too high for the green tier."
        }
        if o.aiScore > 0 {
            return "The signal stack is too weak and too noisy to justify action right now."
        }
        return "No extra intel"
    }
}
