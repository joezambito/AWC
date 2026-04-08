import Foundation

extension WealthEngineStore {
    func activeScanMarketsForCurrentCycle(date: Date = .now, brokerName: String) -> Set<String> {
        _ = date
        _ = brokerName
        return activeExecutionMarkets()
    }

    func activeExecutionRegionLabels() -> Set<String> {
        var enabled: Set<String> = []

        if defaults.object(forKey: StorageKey.scanUS) as? Bool ?? true {
            enabled.insert("US")
        }
        if defaults.object(forKey: StorageKey.scanASX) as? Bool ?? true {
            enabled.insert("AU")
        }
        if defaults.object(forKey: StorageKey.scanCanada) as? Bool ?? true {
            enabled.insert("CA")
        }
        if defaults.object(forKey: StorageKey.scanEurope) as? Bool ?? true {
            enabled.insert("EU")
        }
        if defaults.object(forKey: StorageKey.scanAsia) as? Bool ?? true {
            enabled.insert("APAC")
        }
        if defaults.object(forKey: StorageKey.scanMiddleEast) as? Bool ?? true {
            enabled.insert("ME")
        }
        if defaults.object(forKey: StorageKey.scanRussia) as? Bool ?? true {
            enabled.insert("EU")
        }
        if defaults.object(forKey: StorageKey.scanLatam) as? Bool ?? true {
            enabled.insert("LATAM")
        }
        if defaults.object(forKey: StorageKey.scanAfrica) as? Bool ?? true {
            enabled.insert("AFRICA")
        }
        if defaults.object(forKey: StorageKey.scanFX) as? Bool ?? true {
            enabled.insert("FX")
        }
        if defaults.object(forKey: StorageKey.scanCrypto) as? Bool ?? true {
            enabled.insert("CRYPTO")
        }
        if defaults.object(forKey: StorageKey.scanCommodities) as? Bool ?? true {
            enabled.insert("GLOBAL")
        }

        return enabled
    }

    func isRegionEnabled(_ regionLabel: String) -> Bool {
        activeExecutionRegionLabels().contains(regionLabel)
    }

    func scannedUniverseMarkets() -> Set<String> {
        Set(Self.seededBlueprints().map(\.market))
    }

    func activeExecutionMarkets() -> Set<String> {
        var enabled: Set<String> = []

        if defaults.object(forKey: StorageKey.scanUS) as? Bool ?? true {
            enabled.formUnion(["NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "OTC", "CBOE"])
        }
        if defaults.object(forKey: StorageKey.scanASX) as? Bool ?? true {
            enabled.insert("ASX")
        }
        if defaults.object(forKey: StorageKey.scanCanada) as? Bool ?? true {
            enabled.formUnion(["TSX", "TSXV", "CSE"])
        }
        if defaults.object(forKey: StorageKey.scanEurope) as? Bool ?? true {
            enabled.formUnion(["EU/UK", "LSE", "XETRA", "EURONEXT", "SIX", "OMX", "BIST", "WSE", "BME", "BIT", "VSE", "OSE"])
        }
        if defaults.object(forKey: StorageKey.scanAsia) as? Bool ?? true {
            enabled.formUnion(["TSE", "HKEX", "SSE", "SZSE", "SGX", "NSE", "KRX", "TWSE", "TPEX", "IDX", "BURSA", "SET", "PSE", "HOSE", "HNX", "NZX"])
        }
        if defaults.object(forKey: StorageKey.scanMiddleEast) as? Bool ?? true {
            enabled.formUnion(["TADAWUL", "DFM", "ADX", "QSE", "TASE", "KSE", "MSX", "BHB"])
        }
        if defaults.object(forKey: StorageKey.scanRussia) as? Bool ?? true {
            enabled.insert("MOEX")
        }
        if defaults.object(forKey: StorageKey.scanLatam) as? Bool ?? true {
            enabled.formUnion(["B3", "BMV", "BCBA"])
        }
        if defaults.object(forKey: StorageKey.scanAfrica) as? Bool ?? true {
            enabled.formUnion(["JSE", "EGX"])
        }
        if defaults.object(forKey: StorageKey.scanFX) as? Bool ?? true {
            enabled.insert("FX")
        }
        if defaults.object(forKey: StorageKey.scanCrypto) as? Bool ?? true {
            enabled.insert("CRYPTO")
        }
        if defaults.object(forKey: StorageKey.scanCommodities) as? Bool ?? true {
            enabled.formUnion(["COMMODITY", "CME", "CBOT", "NYMEX", "COMEX", "ICE", "BOND"])
        }

        return enabled
    }

    static func marketSignals(from opportunities: [Opportunity]) -> [MarketSignal] {
        let grouped = Dictionary(grouping: opportunities, by: \.market)

        return grouped.compactMap { market, items in
            guard let lead = items.sorted(by: { lhs, rhs in
                if lhs.rank == rhs.rank {
                    return lhs.confidence > rhs.confidence
                }
                return lhs.rank < rhs.rank
            }).first else {
                return nil
            }

            return MarketSignal(
                symbol: marketSignalLabel(for: market),
                market: market,
                sector: lead.sector,
                theme: lead.catalystBucket
            )
        }
        .sorted { lhs, rhs in
            let leftRank = opportunities.first(where: { $0.market == lhs.market })?.rank ?? .max
            let rightRank = opportunities.first(where: { $0.market == rhs.market })?.rank ?? .max
            return leftRank < rightRank
        }
    }

    static func marketSignalLabel(for market: String) -> String {
        switch market {
        case "NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "OTC", "CBOE":
            return "US"
        case "TSX", "TSXV", "CSE":
            return "CAN"
        case "EU/UK", "LSE", "XETRA", "EURONEXT", "SIX", "OMX", "BIST", "WSE", "BME", "BIT", "VSE", "OSE":
            return "EU/UK"
        case "TSE", "HKEX", "SSE", "SZSE", "SGX", "NSE", "KRX", "TWSE", "TPEX", "IDX", "BURSA", "SET", "PSE", "HOSE", "HNX", "NZX":
            return "ASIA"
        case "TADAWUL", "DFM", "ADX", "QSE", "TASE", "KSE", "MSX", "BHB":
            return "ME"
        case "MOEX":
            return "RUS"
        case "B3", "BMV", "BCBA":
            return "LATAM"
        case "JSE", "EGX":
            return "AFR"
        case "COMMODITY", "CME", "CBOT", "NYMEX", "COMEX", "ICE", "BOND":
            return "COM"
        default:
            return market
        }
    }
}
