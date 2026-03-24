import Foundation

enum WealthMarketRegion {
    case us
    case canada
    case europe
    case australia
    case japan
    case greaterChina
    case asia
    case middleEastAfrica
    case latinAmerica
    case fallback
}

extension WealthMarketCalendar {
    static func canonicalMarket(for market: String) -> String {
        let cleaned = market
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch cleaned {
        case "NASDAQ GS", "NASDAQ GM", "NASDAQ CM", "NASDAQ OMX", "NASDAQ GLOBAL", "NASDAQ GLOBAL SELECT":
            return "NASDAQ"
        case "NEW YORK STOCK EXCHANGE", "NYSE ARCA", "ARCA":
            return "NYSE"
        case "JPX", "TYO", "TOKYO", "TOKYO STOCK EXCHANGE":
            return "TSE"
        case "HKSE":
            return "HKEX"
        case "SHANGHAI", "STAR":
            return "SSE"
        case "SHENZHEN", "CHINEXT":
            return "SZSE"
        case "LONDON", "LON":
            return "LSE"
        case "SAUDI", "SAUDI EXCHANGE":
            return "TADAWUL"
        case "DUBAI":
            return "DFM"
        case "ABU DHABI":
            return "ADX"
        case "CRYPTO MARKET":
            return "CRYPTO"
        case "FOREX":
            return "FX"
        case "COMMODITIES":
            return "COMMODITY"
        default:
            return cleaned
        }
    }

    static func region(for market: String) -> WealthMarketRegion {
        switch canonicalMarket(for: market) {
        case "NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "OTC", "CBOE", "ICE", "BOND", "CME", "CBOT", "NYMEX", "COMEX":
            return .us
        case "TSX", "TSXV", "CSE":
            return .canada
        case "LSE", "EU/UK", "XETRA", "EURONEXT", "SIX", "OMX", "WSE", "BME", "BIT", "VSE", "OSE", "BIST", "MOEX":
            return .europe
        case "ASX", "NZX":
            return .australia
        case "TSE":
            return .japan
        case "HKEX", "SSE", "SZSE":
            return .greaterChina
        case "NSE", "KRX", "TWSE", "TPEX", "SGX", "IDX", "BURSA", "SET", "PSE", "HOSE", "HNX":
            return .asia
        case "TADAWUL", "QSE", "MSX", "BHB", "KSE", "DFM", "ADX", "TASE", "JSE", "EGX":
            return .middleEastAfrica
        case "BMV", "B3", "BCBA":
            return .latinAmerica
        default:
            return .fallback
        }
    }
}
