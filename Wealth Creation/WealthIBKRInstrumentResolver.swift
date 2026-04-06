import Foundation

enum WealthIBKRInstrumentSupportStatus: String, CaseIterable {
    case supportedEquity = "supported_equity"
    case delistedInactive = "delisted_inactive"
    case renamedTicker = "renamed_ticker"
    case nonStandardInstrument = "non_standard_instrument"
    case otcOrForeignNeedsExchange = "otc_or_foreign_needs_exchange"
    case invalidSymbol = "invalid_symbol"

    var uiLabel: String {
        switch self {
        case .supportedEquity:
            return "Live"
        case .delistedInactive:
            return "Delisted"
        case .renamedTicker, .otcOrForeignNeedsExchange:
            return "Needs Mapping"
        case .nonStandardInstrument, .invalidSymbol:
            return "Unsupported"
        }
    }

    var actionTaken: String {
        switch self {
        case .supportedEquity:
            return "Subscribe live STK via SMART"
        case .delistedInactive:
            return "Exclude from live quotes and mark Delisted"
        case .renamedTicker:
            return "Skip live quote until mapped to current ticker"
        case .nonStandardInstrument:
            return "Exclude from normal world-market live quotes"
        case .otcOrForeignNeedsExchange:
            return "Skip live quote until listing venue is mapped"
        case .invalidSymbol:
            return "Skip live quote and mark Unsupported"
        }
    }
}

struct WealthIBKRInstrumentResolution: Identifiable, Hashable {
    let key: WealthBrokerQuoteKey
    let status: WealthIBKRInstrumentSupportStatus
    let resolvedSecType: String?
    let resolvedExchange: String?
    let currency: String?
    let actionTaken: String
    let reason: String
    let contract: WealthIBKRContract?

    var id: String { WealthOpportunityLaneRules.laneKey(symbol: key.symbol, market: key.market) }
    var uiLabel: String { status.uiLabel }
    var isSupportedEquity: Bool { status == .supportedEquity }
}

enum WealthIBKRInstrumentResolver {
    private static let renamedTickers: Set<String> = [
        "CTL", "DNKN", "ERI", "ETFC", "FCAU", "FMCI", "HDS", "HUD",
        "LOGM", "LTM", "MYL", "MYOK", "RMG", "RUBI", "SHLL", "SINA",
        "TCO", "TIF", "WPX"
    ]

    private static let delistedTickers: Set<String> = [
        "ACAM", "CEL", "CZZ", "DNK", "ENT", "FBSS", "LGC", "MGEN",
        "PDLI", "PRSC", "PRVL", "PS", "RTRX", "SMTX", "SZBI", "UROV",
        "WMGI", "WRTC", "WSG"
    ]

    static func resolution(for record: MarketUniverseRecord) -> WealthIBKRInstrumentResolution {
        let key = WealthBrokerQuoteKey(symbol: record.symbol, market: record.market)
        let symbol = record.symbol.uppercased()
        let market = record.market.uppercased()
        let exchange = record.exchange.uppercased()

        if let contract = WealthIBKRContractMapper.contract(for: record),
           contract.secType == "STK",
           contract.exchange == "SMART" {
            return WealthIBKRInstrumentResolution(
                key: key,
                status: .supportedEquity,
                resolvedSecType: contract.secType,
                resolvedExchange: contract.primaryExchange.isEmpty ? contract.exchange : contract.primaryExchange,
                currency: contract.currency,
                actionTaken: WealthIBKRInstrumentSupportStatus.supportedEquity.actionTaken,
                reason: "Mapped as listed equity",
                contract: contract
            )
        }

        if isInvalidSymbol(symbol, market: market, exchange: exchange) {
            return unsupportedResolution(
                key: key,
                status: .invalidSymbol,
                reason: "Invalid or test symbol",
                record: record
            )
        }

        if isDelisted(symbol, market: market, exchange: exchange) {
            return unsupportedResolution(
                key: key,
                status: .delistedInactive,
                reason: "Likely delisted or inactive listing",
                record: record
            )
        }

        if isRenamed(symbol) {
            return unsupportedResolution(
                key: key,
                status: .renamedTicker,
                reason: "Likely renamed or merged ticker",
                record: record
            )
        }

        if isNonStandardInstrument(symbol) {
            return unsupportedResolution(
                key: key,
                status: .nonStandardInstrument,
                reason: "Warrant, right, unit, or preferred-style symbol",
                record: record
            )
        }

        if needsVenueMapping(symbol, market: market, exchange: exchange) {
            return unsupportedResolution(
                key: key,
                status: .otcOrForeignNeedsExchange,
                reason: "Needs exchange or venue mapping",
                record: record
            )
        }

        return unsupportedResolution(
            key: key,
            status: .invalidSymbol,
            reason: "No valid IBKR equity contract mapping",
            record: record
        )
    }

    @MainActor
    static func supportedContract(for record: MarketUniverseRecord) -> WealthIBKRContract? {
        let resolution = resolution(for: record)
        return resolution.isSupportedEquity ? resolution.contract : nil
    }

    @MainActor
    static func reportRows(for records: [MarketUniverseRecord]) -> [WealthIBKRInstrumentResolution] {
        records
            .map(resolution(for:))
            .sorted { lhs, rhs in
                if lhs.status.rawValue != rhs.status.rawValue {
                    return lhs.status.rawValue < rhs.status.rawValue
                }
                if lhs.key.market != rhs.key.market {
                    return lhs.key.market < rhs.key.market
                }
                return lhs.key.symbol < rhs.key.symbol
            }
    }

    private static func unsupportedResolution(
        key: WealthBrokerQuoteKey,
        status: WealthIBKRInstrumentSupportStatus,
        reason: String,
        record: MarketUniverseRecord
    ) -> WealthIBKRInstrumentResolution {
        WealthIBKRInstrumentResolution(
            key: key,
            status: status,
            resolvedSecType: nil,
            resolvedExchange: fallbackExchangeLabel(for: record),
            currency: record.currency.isEmpty ? nil : record.currency,
            actionTaken: status.actionTaken,
            reason: reason,
            contract: nil
        )
    }

    private static func isRenamed(_ symbol: String) -> Bool {
        renamedTickers.contains(symbol)
    }

    private static func isDelisted(_ symbol: String, market: String, exchange: String) -> Bool {
        if delistedTickers.contains(symbol) { return true }
        if symbol.hasSuffix("Q") { return true }
        return market == "UNKNOWN" && exchange.isEmpty && symbol.count <= 4 && !isNonStandardInstrument(symbol)
    }

    private static func isNonStandardInstrument(_ symbol: String) -> Bool {
        let upper = symbol.uppercased()
        if upper.contains("-WT") || upper.hasSuffix("WT") || upper.hasSuffix("WS") || upper.hasSuffix("-W") {
            return true
        }
        if upper.contains("'U") || upper.contains("-U") || upper.hasSuffix("U") && upper.count > 4 {
            return true
        }
        if upper.contains("-P") || upper.contains(" PR") || upper.contains("PFD") {
            return true
        }
        return false
    }

    private static func needsVenueMapping(_ symbol: String, market: String, exchange: String) -> Bool {
        if ["OTC", "PNK", "OBB"].contains(exchange) { return true }
        if market == "UNKNOWN" || market == "BATS BZX EXCHANGE" || market == "US24_MARKET" {
            return true
        }
        if symbol.hasSuffix("F") || symbol.hasSuffix("Y") {
            return true
        }
        return false
    }

    private static func isInvalidSymbol(_ symbol: String, market: String, exchange: String) -> Bool {
        if symbol.hasPrefix("YTEST") { return true }
        if symbol.range(of: #"^[A-Z0-9\-\.'\/]+$"#, options: .regularExpression) == nil {
            return true
        }
        if market == "US24_MARKET" || exchange == "NAE" {
            return true
        }
        return false
    }

    private static func fallbackExchangeLabel(for record: MarketUniverseRecord) -> String? {
        if !record.exchange.isEmpty { return record.exchange.uppercased() }
        if !record.market.isEmpty { return record.market.uppercased() }
        return nil
    }
}
