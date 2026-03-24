import Foundation

extension WealthEngineStore {
    static let expandedSeededBlueprintCatalog: [OpportunityBlueprint] = expandedSeedSpecs.map(makeExpandedBlueprint)

    private static let expandedSeedSpecs: [ExpandedSeedSpec] = [
        seed("MSFT", "NASDAQ", "Software", 428.12, .active, 1.1), seed("NFLX", "NASDAQ", "Communication", 617.30, .surge, 2.0), seed("CRM", "NYSE", "Software", 318.44, .active, 1.0), seed("NOW", "NYSE", "Software", 812.20, .active, 0.9),
        seed("TTD", "NASDAQ", "Advertising", 87.62, .surge, 2.2), seed("UBER", "NYSE", "Transport", 84.11, .active, 1.4), seed("PANW", "NASDAQ", "Cybersecurity", 342.55, .active, 1.0), seed("MU", "NASDAQ", "Semiconductors", 133.84, .surge, 1.8),
        seed("ANET", "NYSE", "Networking", 307.16, .active, 1.1), seed("SNOW", "NYSE", "Software", 188.24, .watch, 0.8), seed("APP", "NASDAQ", "AdTech", 96.44, .surge, 2.3), seed("COIN", "NASDAQ", "Fintech", 236.90, .surge, 2.6),
        seed("RBLX", "NYSE", "Consumer Tech", 48.26, .watch, 0.9), seed("V", "NYSE", "Payments", 301.55, .defensive, 0.4), seed("MA", "NYSE", "Payments", 488.73, .defensive, 0.3), seed("JPM", "NYSE", "Banking", 214.88, .active, 0.8),
        seed("BAC", "NYSE", "Banking", 41.22, .monitor, 0.5), seed("XOM", "NYSE", "Energy", 117.92, .monitor, 0.4), seed("CVX", "NYSE", "Energy", 168.30, .monitor, 0.3), seed("LLY", "NYSE", "Healthcare", 821.40, .active, 0.8),
        seed("ABBV", "NYSE", "Healthcare", 185.10, .defensive, 0.3), seed("WMT", "NYSE", "Consumer Staples", 64.72, .defensive, 0.4), seed("MRVL", "NASDAQ", "Semiconductors", 88.48, .surge, 1.9), seed("SOFI", "NASDAQ", "Fintech", 11.92, .watch, 1.2),
        seed("HOOD", "NASDAQ", "Fintech", 22.41, .surge, 2.0), seed("IWM", "ETF", "ETF", 228.44, .watch, 0.7), seed("DIA", "ETF", "ETF", 412.85, .defensive, 0.3), seed("XLE", "ETF", "ETF", 97.18, .monitor, 0.5),
        seed("XLF", "ETF", "ETF", 45.24, .monitor, 0.4), seed("HYG", "ETF", "ETF", 78.16, .defensive, 0.2), seed("TLT", "ETF", "ETF", 95.82, .defensive, 0.3), seed("EFA", "ETF", "ETF", 82.44, .watch, 0.5),
        seed("EWZ", "ETF", "ETF", 32.70, .watch, 0.9), seed("FXI", "ETF", "ETF", 27.62, .watch, 0.8), seed("VNQ", "REIT", "REIT", 88.34, .monitor, 0.3), seed("NVO", "ADR", "Healthcare", 124.18, .defensive, 0.4),
        seed("TM", "ADR", "Autos", 241.66, .monitor, 0.4), seed("BABA", "ADR", "Consumer Tech", 102.34, .watch, 1.1), seed("ASML", "ADR", "Semiconductors", 955.22, .active, 0.9), seed("TSM", "ADR", "Semiconductors", 188.47, .active, 1.3),

        seed("CNQ", "TSX", "Energy", 53.42, .monitor, 0.5), seed("SU", "TSX", "Energy", 45.16, .monitor, 0.4), seed("CP", "TSX", "Transport", 119.42, .active, 0.7), seed("BAM", "TSX", "Asset Management", 61.88, .active, 0.8),
        seed("TRI", "TSX", "Information Services", 233.72, .defensive, 0.3), seed("SHOP", "TSX", "Software", 122.14, .active, 1.2),

        seed("RR", "LSE", "Industrials", 4.82, .watch, 0.8), seed("HSBA", "LSE", "Banking", 7.64, .monitor, 0.4), seed("ULVR", "LSE", "Consumer Staples", 50.36, .defensive, 0.2), seed("REL", "LSE", "Information Services", 39.44, .defensive, 0.3),
        seed("DB1", "XETRA", "Exchange", 212.70, .active, 0.8), seed("IFX", "XETRA", "Semiconductors", 37.24, .active, 1.1), seed("MC", "EURONEXT", "Luxury", 781.00, .watch, 0.7), seed("AIR", "EURONEXT", "Industrials", 178.52, .watch, 0.8),
        seed("BNP", "EURONEXT", "Banking", 72.11, .monitor, 0.4), seed("NESN", "SIX", "Consumer Staples", 108.66, .defensive, 0.2), seed("NOVO-B", "OMX", "Healthcare", 96.44, .monitor, 0.4), seed("SAN", "BME", "Banking", 5.74, .monitor, 0.5),
        seed("ENEL", "BIT", "Utilities", 7.85, .defensive, 0.2), seed("PKN", "WSE", "Energy", 19.66, .monitor, 0.4), seed("NHY", "OSE", "Materials", 6.47, .watch, 0.6),

        seed("TCS", "NSE", "Software", 48.62, .active, 0.9), seed("HDFCBANK", "NSE", "Banking", 23.11, .monitor, 0.5), seed("KOTAKBANK", "NSE", "Banking", 24.38, .monitor, 0.4), seed("9984", "TSE", "Communication", 74.26, .watch, 1.0),
        seed("6501", "TSE", "Industrials", 28.41, .watch, 0.8), seed("6758", "TSE", "Consumer Tech", 83.14, .active, 0.9), seed("2308", "TWSE", "Semiconductors", 16.32, .surge, 1.9), seed("2317", "TWSE", "Electronics", 6.18, .watch, 0.7),
        seed("0700", "HKEX", "Communication", 51.66, .watch, 0.8), seed("1211", "HKEX", "Autos", 29.74, .watch, 1.0), seed("9988", "HKEX", "Consumer Tech", 11.28, .watch, 0.9), seed("035420", "KRX", "Internet", 121.40, .watch, 0.8),
        seed("066570", "KRX", "Electronics", 63.44, .monitor, 0.5), seed("DBS", "SGX", "Banking", 29.42, .monitor, 0.4), seed("PTT", "SET", "Energy", 1.02, .monitor, 0.3), seed("TEL", "PSE", "Telecom", 22.15, .monitor, 0.4),
        seed("FPT", "HOSE", "Software", 5.36, .watch, 0.9), seed("VIC", "HOSE", "Property", 2.48, .speculative, -0.3), seed("FPH", "NZX", "Healthcare", 21.13, .monitor, 0.5),

        seed("QNBK", "QSE", "Banking", 4.88, .monitor, 0.3), seed("SABIC", "TADAWUL", "Materials", 19.74, .monitor, 0.4), seed("ALDAR", "ADX", "Property", 1.87, .watch, 0.7), seed("ADNOCGAS", "ADX", "Energy", 0.94, .monitor, 0.4),
        seed("EMAAR", "DFM", "Property", 3.01, .watch, 0.6), seed("TEVA", "TASE", "Healthcare", 16.37, .monitor, 0.4), seed("NBK", "KSE", "Banking", 2.87, .monitor, 0.3), seed("BANKMUSCAT", "MSX", "Banking", 0.72, .speculative, -0.1),
        seed("NBB", "BHB", "Banking", 0.88, .speculative, -0.2), seed("MTN", "JSE", "Telecom", 7.42, .monitor, 0.4), seed("SOL", "JSE", "Energy", 13.18, .watch, 0.8), seed("FSR", "JSE", "Banking", 3.94, .monitor, 0.4),
        seed("CIB", "EGX", "Banking", 1.55, .speculative, 0.2),

        seed("ITUB4", "B3", "Banking", 6.12, .monitor, 0.5), seed("PETR4", "B3", "Energy", 6.58, .watch, 0.7), seed("VALE3", "B3", "Mining", 11.18, .watch, 0.8), seed("WALMEX", "BMV", "Consumer Staples", 3.18, .defensive, 0.2),
        seed("FEMSAUBD", "BMV", "Consumer Staples", 9.74, .defensive, 0.3), seed("GGAL", "BCBA", "Banking", 8.34, .watch, 0.9), seed("YPF", "BCBA", "Energy", 31.60, .watch, 1.0),

        seed("ETH", "CRYPTO", "Digital Assets", 4_280.00, .surge, 3.1), seed("SOLANA", "CRYPTO", "Digital Assets", 186.42, .surge, 3.6), seed("XRP", "CRYPTO", "Digital Assets", 0.86, .watch, 1.8), seed("EURUSD", "FX", "FX", 1.09, .monitor, 0.2),
        seed("USDJPY", "FX", "FX", 149.80, .monitor, 0.2), seed("SILVER", "COMMODITY", "Metals", 24.70, .watch, 0.6), seed("COPPER", "COMMODITY", "Metals", 4.18, .watch, 0.7), seed("SI", "COMEX", "Metals Futures", 24.84, .watch, 0.9),
        seed("HG", "COMEX", "Metals Futures", 4.21, .watch, 0.8), seed("NG", "NYMEX", "Energy Futures", 2.04, .speculative, 1.3), seed("ZW", "CBOT", "Agriculture Futures", 5.88, .monitor, 0.3), seed("DX", "ICE", "Dollar Futures", 103.14, .monitor, 0.2),
        seed("LQD", "BOND", "Bonds", 108.72, .defensive, 0.2)
    ]
}
