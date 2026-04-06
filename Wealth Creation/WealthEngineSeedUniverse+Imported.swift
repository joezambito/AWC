import Foundation

extension WealthEngineStore {
    private static var cachedUniverseDrivenBlueprintCatalog: [OpportunityBlueprint] = []
    private static var cachedUniverseDrivenBlueprintCatalogSignature = ""

    @MainActor
    static func isUsingImportedUniverseSeedSource() -> Bool {
        let universeSource = currentUniverseSeedSource()
        return !universeSource.records.isEmpty
    }

    @MainActor
    static func universeDrivenBlueprintCatalog() -> [OpportunityBlueprint] {
        let universeSource = currentUniverseSeedSource()
        let records = deduplicatedUniverseRecords(universeSource.records)
        guard !records.isEmpty else { return [] }

        let signature = [
            universeSource.label,
            String(records.count),
            universeSource.signature
        ].joined(separator: "|")

        if signature == cachedUniverseDrivenBlueprintCatalogSignature {
            return cachedUniverseDrivenBlueprintCatalog
        }

        let catalog = buildImportedUniverseBlueprintCatalog(from: records)
        cachedUniverseDrivenBlueprintCatalogSignature = signature
        cachedUniverseDrivenBlueprintCatalog = catalog
        return catalog
    }

    @MainActor
    private static func currentUniverseSeedSource() -> (label: String, signature: String, records: [MarketUniverseRecord]) {
        let universeStore = WealthMarketUniverseStore.shared
        let persistedRecords = universeStore.records
        if !persistedRecords.isEmpty {
            let marker = [
                universeStore.sourceLabel,
                universeStore.lastSuccessfulLoadAt?.description ?? "none",
                String(persistedRecords.count)
            ].joined(separator: "|")
            return ("persisted", marker, persistedRecords)
        }

        let loaderRecords = WealthMarketUniverseLoader.records()
        if !loaderRecords.isEmpty {
            return ("loader", "loader|\(loaderRecords.count)", loaderRecords)
        }

        return ("empty", "empty", [])
    }

    private static func deduplicatedUniverseRecords(_ records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
        var seen: Set<String> = []
        return records.filter { seen.insert($0.id).inserted }
    }

    private static func buildImportedUniverseBlueprintCatalog(from loaderRecords: [MarketUniverseRecord]) -> [OpportunityBlueprint] {
        let activeRecords = loaderRecords.filter(\.isActive)
        let eligibleRecords = activeRecords.filter(isEligibleUniverseRecord)

        WealthPipelineTraceLogger.logExpandedUniverse(
            total: eligibleRecords.count,
            dropped: max(0, loaderRecords.count - eligibleRecords.count),
            markets: eligibleRecords.map(\.market)
        )

        guard !eligibleRecords.isEmpty else { return [] }

        let recordsByRegion = Dictionary(grouping: eligibleRecords, by: \.regionCode)
        let orderedRegions = ["US", "AU", "CA", "EU", "APAC", "ME", "LATAM", "AFRICA", "GLOBAL", "FX", "CRYPTO", "UNKNOWN"]
        let remainingRegions = Set(recordsByRegion.keys).subtracting(orderedRegions).sorted()

        var selected: [MarketUniverseRecord] = []
        var seenKeys: Set<String> = []

        for region in orderedRegions + remainingRegions {
            let regionRecords = (recordsByRegion[region] ?? [])
                .sorted(by: universeRecordOrder)
                .prefix(regionCap(for: region))

            for record in regionRecords {
                guard seenKeys.insert(record.id).inserted else { continue }
                selected.append(record)
            }
        }

        WealthPipelineTraceLogger.logSeedUniverse(selected.map(makeImportedUniverseBlueprint))

        return selected.map(makeImportedUniverseBlueprint)
    }

    private static func isEligibleUniverseRecord(_ record: MarketUniverseRecord) -> Bool {
        let market = record.market.uppercased()
        let exchange = record.exchange.uppercased()

        guard !record.symbol.isEmpty else { return false }
        guard !exchange.contains("OTC BULLETIN") else { return false }
        guard !market.contains("OTC BULLETIN") else { return false }
        return true
    }

    private static func regionCap(for region: String) -> Int {
        switch region {
        case "US": return 128623
        case "AU": return 128623
        case "CA": return 128623
        case "EU": return 128623
        case "APAC": return 128623
        case "ME": return 128623
        case "LATAM": return 128623
        case "AFRICA": return 128623
        case "GLOBAL": return 128623
        case "FX": return 128623
        case "CRYPTO": return 128623
        case "UNKNOWN": return 128623
        default: return 128623
        }
    }

    private static func universeRecordOrder(lhs: MarketUniverseRecord, rhs: MarketUniverseRecord) -> Bool {
        let leftScore = universePriorityScore(for: lhs)
        let rightScore = universePriorityScore(for: rhs)

        if leftScore != rightScore { return leftScore > rightScore }
        if lhs.regionCode != rhs.regionCode { return lhs.regionCode < rhs.regionCode }
        return lhs.symbol < rhs.symbol
    }

    private static func universePriorityScore(for record: MarketUniverseRecord) -> Int {
        var score = 0
        let assetType = record.normalizedAssetType
        let market = record.market.uppercased()
        let exchange = record.exchange.uppercased()

        if record.companyName?.isEmpty == false { score += 40 }
        if !record.currency.isEmpty { score += 8 }
        if !record.country.isEmpty { score += 8 }
        if !record.provider.isEmpty { score += 6 }

        switch market {
        case "NASDAQ", "NYSE", "ASX", "TSX", "LSE", "XETRA", "EURONEXT", "TSE", "HKEX", "NSE", "KRX", "TWSE", "SGX":
            score += 40
        case "FX", "CRYPTO", "CME", "CBOT", "COMEX", "NYMEX", "ICE", "BOND":
            score += 28
        default:
            score += 18
        }

        if assetType.contains("equit") || assetType.contains("stock") { score += 36 }
        if assetType.contains("etf") || assetType.contains("reit") || assetType.contains("adr") { score += 24 }
        if assetType.contains("crypto") || assetType.contains("currenc") { score += 18 }
        if assetType.contains("bond") || assetType.contains("index") { score += 16 }
        if exchange.contains("OTC") || market.contains("OTC") { score -= 90 }

        score += Int(deterministicUnit("\(record.symbol)-\(record.market)-priority") * 15)
        return score
    }

    private static func makeImportedUniverseBlueprint(from record: MarketUniverseRecord) -> OpportunityBlueprint {
        let spec = ExpandedSeedSpec(
            symbol: record.symbol,
            market: normalizedEngineMarket(for: record),
            sector: normalizedEngineSector(for: record),
            price: generatedSeedPrice(for: record),
            tone: generatedTone(for: record),
            change: generatedPriceChange(for: record)
        )

        return makeExpandedBlueprint(from: spec)
    }

    private static func normalizedEngineMarket(for record: MarketUniverseRecord) -> String {
        let market = record.market.uppercased()
        let assetType = record.normalizedAssetType

        if assetType.contains("currenc") { return "FX" }
        if assetType.contains("crypto") { return "CRYPTO" }
        if assetType.contains("bond") && market == "GLOBAL" { return "BOND" }
        if market == "GLOBAL" && assetType.contains("index") { return "ETF" }
        return market
    }

    private static func normalizedEngineSector(for record: MarketUniverseRecord) -> String {
        if let bundledSector = bundledSectorName(for: record), !bundledSector.isEmpty {
            return bundledSector
        }

        let sector = record.sector.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sector.isEmpty, sector != "UNKNOWN" {
            return sector
        }

        switch record.regionCode {
        case "FX": return "FX"
        case "CRYPTO": return "Digital Assets"
        case "GLOBAL": return "Global Macro"
        default: return "Global Equity"
        }
    }

    private static func generatedSeedPrice(for record: MarketUniverseRecord) -> Double {
        let unit = deterministicUnit("\(record.symbol)-\(record.market)-price")
        let assetType = record.normalizedAssetType
        let market = record.market.uppercased()

        if assetType.contains("currenc") || market == "FX" {
            return roundTo(0.55 + unit * 1.35, places: 4)
        }

        if assetType.contains("crypto") || market == "CRYPTO" {
            if unit < 0.18 { return roundTo(0.08 + unit * 4, places: 4) }
            if unit < 0.62 { return roundTo(8 + unit * 550, places: 2) }
            return roundTo(2_000 + unit * 115_000, places: 2)
        }

        if assetType.contains("bond") || market == "BOND" {
            return roundTo(78 + unit * 42, places: 2)
        }

        if assetType.contains("etf") || assetType.contains("reit") || assetType.contains("index") {
            return roundTo(18 + unit * 310, places: 2)
        }

        if record.symbol.allSatisfy(\.isNumber) {
            return roundTo(8 + unit * 210, places: 2)
        }

        return roundTo(3 + unit * 520, places: 2)
    }

    private static func generatedTone(for record: MarketUniverseRecord) -> ExpandedTone {
        let unit = deterministicUnit("\(record.symbol)-\(record.market)-tone")
        switch unit {
        case ..<0.11: return .surge
        case ..<0.34: return .active
        case ..<0.58: return .watch
        case ..<0.80: return .monitor
        case ..<0.93: return .defensive
        default: return .speculative
        }
    }

    private static func generatedPriceChange(for record: MarketUniverseRecord) -> Double {
        let unit = deterministicUnit("\(record.symbol)-\(record.market)-change")
        return roundTo((unit - 0.5) * 6.4, places: 2)
    }

    private static func bundledSectorName(for record: MarketUniverseRecord) -> String? {
        guard record.provider.hasPrefix("Bundled JSON|") else { return nil }
        let sector = String(record.provider.dropFirst("Bundled JSON|".count))
        return sector.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func deterministicUnit(_ value: String) -> Double {
        let hash = value.unicodeScalars.reduce(UInt64(1469598103934665603)) { partial, scalar in
            let mixed = partial ^ UInt64(scalar.value)
            return mixed &* 1099511628211
        }
        return Double(hash % 10_000) / 10_000
    }

    private static func roundTo(_ value: Double, places: Int) -> Double {
        let scale = pow(10.0, Double(places))
        return (value * scale).rounded() / scale
    }
}
