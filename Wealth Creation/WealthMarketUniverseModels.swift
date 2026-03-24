import SwiftUI

enum MarketUniverseLabelBand: String, Hashable, CaseIterable {
    case green
    case blue
    case purple
    case red

    var title: String {
        switch self {
        case .green: return "GREEN"
        case .blue: return "BLUE"
        case .purple: return "PURPLE"
        case .red: return "RED"
        }
    }

    var tint: Color {
        switch self {
        case .green: return WealthTheme.green
        case .blue: return WealthTheme.blue
        case .purple: return WealthTheme.purple
        case .red: return WealthTheme.red
        }
    }
}

struct MarketUniverseEntry: Identifiable, Hashable {
    let id: String
    let symbol: String
    let market: String
    let marketDisplayLabel: String
    let region: String
    let sector: String
    let price: Double
    let priceChangePercent: Double
    let hasQuoteData: Bool
    let isDelayed: Bool
    let priceText: String
    let changeText: String
    let confidenceText: String
    let statusText: String
    let dataAgeText: String
    let nextTradeText: String
    let whyText: String
    let tint: Color
    let aiLabelBand: MarketUniverseLabelBand?
    let shieldExitPrice: Double?
    let surgeExitPrice: Double?
    let shieldTriggerPercent: Double?
    let surgeTriggerPercent: Double?
}

struct MarketUniverseRecord: Codable, Identifiable, Hashable {
    let symbol: String
    let name: String
    let assetType: String
    let country: String
    let region: String
    let exchange: String
    let market: String
    let currency: String
    let isin: String
    let provider: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case symbol
        case name
        case assetType = "asset_type"
        case country
        case region
        case exchange
        case market
        case currency
        case isin
        case provider
        case isActive = "is_active"
    }

    var id: String {
        [symbol, market, assetType, exchange, country]
            .joined(separator: "-")
            .uppercased()
    }

    var companyName: String? {
        if let definition = WealthMarketInstrumentCatalog.definition(symbol: symbol, market: market) {
            return definition.name
        }
        return name.isEmpty ? nil : name
    }

    var normalizedAssetType: String {
        assetType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isWorldShareInstrument: Bool {
        isActive &&
        !symbol.hasPrefix("^") &&
        [
            "equity",
            "equities",
            "stock",
            "stocks"
        ].contains(normalizedAssetType)
    }

    var sector: String {
        assetTypeDisplay
    }

    var isIndexInstrument: Bool {
        assetType.lowercased() == "index"
    }

    var assetTypeDisplay: String {
        if isIndexInstrument {
            return "INDEX"
        }
        return assetType
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }

    var regionCode: String {
        let marketRegion = WealthMarketLabels.region(for: market)
        if marketRegion != market.uppercased() {
            return marketRegion
        }

        switch region {
        case "North America":
            return country == "Canada" ? "CA" : "US"
        case "South America":
            return "LATAM"
        case "Europe":
            return "EU"
        case "Africa":
            return "AFRICA"
        case "Asia":
            return "APAC"
        case "Middle East":
            return "ME"
        case "Oceania":
            return "AU"
        case "Global":
            return "GLOBAL"
        default:
            return "UNKNOWN"
        }
    }

    var marketDisplayLabel: String {
        let label = WealthMarketLabels.display(for: market)
        if label != market.uppercased() || exchange.isEmpty {
            return label
        }
        return exchange.uppercased()
    }

    var browserCountryLabel: String {
        country.isEmpty ? "Unknown" : country
    }

    var browserRegionLabel: String {
        region.isEmpty ? "Unknown" : region
    }

    var browserExchangeLabel: String {
        exchange.isEmpty ? "Unknown" : exchange
    }

    var browserCurrencyLabel: String {
        currency.isEmpty ? "Unknown" : currency
    }

    var providerFallbackSymbols: [String] {
        WealthMarketInstrumentCatalog.providerFallbackSymbols(symbol: symbol, market: market)
    }

    nonisolated static func browserOrder(lhs: MarketUniverseRecord, rhs: MarketUniverseRecord) -> Bool {
        if lhs.symbol != rhs.symbol { return lhs.symbol < rhs.symbol }
        if lhs.exchange != rhs.exchange { return lhs.exchange < rhs.exchange }
        if lhs.market != rhs.market { return lhs.market < rhs.market }
        if lhs.assetType != rhs.assetType { return lhs.assetType < rhs.assetType }
        return lhs.country < rhs.country
    }
}

struct MarketUniverseLoadResult {
    let records: [MarketUniverseRecord]
    let sourceLabel: String
    let warningMessage: String?
    let errorMessage: String?
}

struct MarketRegionCalendarEntry: Identifiable, Hashable {
    let id: String
    let region: String
    let market: String
    let marketCount: Int
    let state: MarketSessionState
    let nextTradeText: String
}

struct MarketRoutingSnapshot: Identifiable, Hashable {
    let id: String
    let label: String
    let detail: String
    let tint: Color
}
