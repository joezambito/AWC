import Foundation

extension WealthEngineStore {
    static func seed(
        _ symbol: String,
        _ market: String,
        _ sector: String,
        _ price: Double,
        _ tone: ExpandedTone,
        _ change: Double
    ) -> ExpandedSeedSpec {
        ExpandedSeedSpec(symbol: symbol, market: market, sector: sector, price: price, tone: tone, change: change)
    }

    static func shouldStayCatalogFirst(_ spec: ExpandedSeedSpec) -> Bool {
        let primaryExecutionMarkets = Set(["NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "TSX", "ASX", "LSE", "XETRA", "EURONEXT", "CME", "CBOT", "COMEX", "NYMEX", "ICE", "FX", "CRYPTO"])
        if primaryExecutionMarkets.contains(spec.market) { return false }
        if spec.symbol.allSatisfy(\.isNumber) { return true }
        return true
    }

    static func dataOrigin(for market: String) -> String {
        switch market {
        case "CRYPTO": return "Cross-Market Feed · Smart Money Scan"
        case "FX": return "FX Feed · Macro Scan"
        case "COMMODITY", "BOND", "CME", "CBOT", "COMEX", "NYMEX", "ICE": return "Derivatives Feed · Macro Scan"
        case "ETF", "REIT": return "ETF Feed · Structured Scan"
        case "ADR": return "ADR Feed · Structured Scan"
        default: return "Price/Volume Feed · Structured Scan"
        }
    }

    static func intelligenceDrivers(for tone: ExpandedTone, sector: String, shelfOnly: Bool) -> [String] {
        if shelfOnly {
            return ["Market Shelf Coverage", "\(sector) Theme Scan", "Needs Company Evidence"]
        }

        switch tone {
        case .surge:
            return ["Volume Expansion", "\(sector) Momentum", "Search Trend Lift"]
        case .active:
            return ["Research Consensus", "\(sector) Rotation", "Institutional Support"]
        case .watch:
            return ["Sector Watch", "Trend Confirmation", "Catalyst Monitoring"]
        case .monitor:
            return ["Allocation Flow", "Macro Alignment", "Risk Control"]
        case .defensive:
            return ["Capital Preservation", "Quality Filter", "Lower Beta"]
        case .speculative:
            return ["Recovery Scan", "Volatility Probe", "Event Watch"]
        }
    }

    static func intelligenceChannels(for market: String, shelfOnly: Bool) -> [String] {
        if shelfOnly {
            return ["World Market Shelf", "Regional Scan", "Structured Feed"]
        }

        switch market {
        case "CRYPTO": return ["Cross-Market Feed", "Web/App Tracker", "Options Tape"]
        case "FX": return ["Macro Scan", "Rates Feed", "Futures Tape"]
        case "COMMODITY", "BOND", "CME", "CBOT", "COMEX", "NYMEX", "ICE": return ["Macro Scan", "Futures Tape", "Research Mesh"]
        default: return ["Research Mesh", "Public News", "Price/Volume Feed"]
        }
    }

    static func capitalFitLabel(for price: Double) -> String {
        if price <= 60 { return "EASY FIT" }
        if price <= 260 { return "GOOD FIT" }
        return "HEAVY FIT"
    }

    static func liquidity(for price: Double, tone: ExpandedTone, shelfOnly: Bool) -> Double {
        let base = max(80_000_000, price * 6_500_000)
        let multiplier: Double

        switch tone {
        case .surge: multiplier = 2.7
        case .active: multiplier = 2.1
        case .watch: multiplier = 1.5
        case .monitor: multiplier = 1.2
        case .defensive: multiplier = 1.3
        case .speculative: multiplier = 0.7
        }

        return base * (shelfOnly ? max(0.7, multiplier - 0.6) : multiplier)
    }
}
