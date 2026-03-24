import Foundation

enum WealthMarketLabels {
    static func display(for market: String) -> String {
        switch market.uppercased() {
        case "NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "OTC", "CBOE": return "US"
        case "ASX": return "AUSTRALIA"
        case "TSX", "TSXV", "CSE": return "CANADA"
        case "EU/UK", "LSE", "XETRA", "EURONEXT", "SIX", "OMX", "BME", "BIT", "VSE", "WSE", "OSE", "BIST", "MOEX": return "EUROPE"
        case "TSE", "HKEX", "SSE", "SZSE", "NSE", "KRX", "TWSE", "TPEX", "IDX", "BURSA", "SET", "PSE", "HOSE", "HNX", "SGX", "NZX": return "ASIA PACIFIC"
        case "TADAWUL", "DFM", "ADX", "QSE", "TASE", "KSE", "MSX", "BHB": return "MIDDLE EAST"
        case "B3", "BMV", "BCBA": return "LATAM"
        case "JSE", "EGX": return "AFRICA"
        case "FX": return "FX MARKET"
        case "CRYPTO": return "CRYPTO MARKET"
        case "COMMODITY", "CME", "CBOT", "COMEX", "NYMEX", "ICE", "BOND": return "GLOBAL DERIVATIVES"
        default: return market.uppercased()
        }
    }

    static func region(for market: String) -> String {
        switch market.uppercased() {
        case "NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "OTC", "CBOE": return "US"
        case "ASX": return "AU"
        case "TSX", "TSXV", "CSE": return "CA"
        case "EU/UK", "LSE", "XETRA", "EURONEXT", "SIX", "OMX", "BME", "BIT", "VSE", "WSE", "OSE", "BIST", "MOEX": return "EU"
        case "TSE", "HKEX", "SSE", "SZSE", "NSE", "KRX", "TWSE", "TPEX", "IDX", "BURSA", "SET", "PSE", "HOSE", "HNX", "SGX", "NZX": return "APAC"
        case "TADAWUL", "DFM", "ADX", "QSE", "TASE", "KSE", "MSX", "BHB": return "ME"
        case "B3", "BMV", "BCBA": return "LATAM"
        case "JSE", "EGX": return "AFRICA"
        case "FX": return "FX"
        case "CRYPTO": return "CRYPTO"
        case "COMMODITY", "CME", "CBOT", "COMEX", "NYMEX", "ICE", "BOND": return "GLOBAL"
        default: return market.uppercased()
        }
    }
}
