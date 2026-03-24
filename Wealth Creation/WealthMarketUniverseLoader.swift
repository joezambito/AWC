import Foundation

enum WealthMarketUniverseLoader {
    nonisolated static func records() -> [MarketUniverseRecord] {
        load().records
    }

    nonisolated static func load() -> MarketUniverseLoadResult {
        loadRecords()
    }

    nonisolated static func invalidateCache() {
        // No-op on purpose. The loader now always reads a fresh snapshot.
    }

    nonisolated private static func loadRecords() -> MarketUniverseLoadResult {
        let parquetURLs = candidateURLs(fileName: "global_universe", fileExtension: "parquet")
        let csvURLs = candidateURLs(fileName: "global_universe", fileExtension: "csv")
        let parquetWarning = parquetURLs.isEmpty
            ? nil
            : "Parquet universe detected. This build is using the CSV fallback."

        for csvURL in csvURLs {
            do {
                let content = try String(contentsOf: csvURL, encoding: .utf8)
                let records = try parseCSV(content)
                let mergedRecords = mergedWithCatalog(records)
                guard !mergedRecords.isEmpty else { continue }

                return MarketUniverseLoadResult(
                    records: mergedRecords,
                    sourceLabel: "CSV \(csvURL.lastPathComponent)",
                    warningMessage: parquetWarning,
                    errorMessage: nil
                )
            } catch {
                return MarketUniverseLoadResult(
                    records: [],
                    sourceLabel: "CSV ERROR",
                    warningMessage: parquetWarning,
                    errorMessage: "Failed to load normalized universe from \(csvURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
        }

        let bundledJSONRecords = loadBundledJSONUniverse()
        if !bundledJSONRecords.isEmpty {
            return MarketUniverseLoadResult(
                records: mergedWithCatalog(bundledJSONRecords),
                sourceLabel: "BUNDLED JSON",
                warningMessage: parquetWarning ?? "CSV universe missing. Using bundled regional market files.",
                errorMessage: nil
            )
        }

        if let parquetURL = parquetURLs.first {
            return MarketUniverseLoadResult(
                records: [],
                sourceLabel: "PARQUET ONLY",
                warningMessage: nil,
                errorMessage: "Found \(parquetURL.lastPathComponent), but this app build needs the CSV fallback file global_universe.csv to browse instruments."
            )
        }

        return MarketUniverseLoadResult(
            records: [],
            sourceLabel: "MISSING",
            warningMessage: nil,
            errorMessage: "No normalized universe file was found. Add data/markets/global_universe.csv or include bundled MarketUniverse JSON files."
        )
    }

    nonisolated private static func candidateURLs(fileName: String, fileExtension: String) -> [URL] {
        let fileManager = FileManager.default
        var urls: [URL] = []

        if let bundleURL = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExtension,
            subdirectory: "data/markets"
        ) {
            urls.append(bundleURL)
        }

        if let bundleURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            urls.append(bundleURL)
        }

        let searchDirectories: [FileManager.SearchPathDirectory] = [
            .applicationSupportDirectory,
            .documentDirectory
        ]

        for directory in searchDirectories {
            guard let baseURL = try? fileManager.url(
                for: directory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ) else {
                continue
            }

            urls.append(baseURL.appendingPathComponent("\(fileName).\(fileExtension)"))
            urls.append(
                baseURL
                    .appendingPathComponent("data", isDirectory: true)
                    .appendingPathComponent("markets", isDirectory: true)
                    .appendingPathComponent("\(fileName).\(fileExtension)")
            )
        }

        var seen: Set<String> = []
        return urls
            .filter { seen.insert($0.path).inserted }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    nonisolated private static func loadBundledJSONUniverse() -> [MarketUniverseRecord] {
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        let bundleRoot = Bundle.main.resourceURL
        let localRoot = Bundle(for: BundleToken.self).resourceURL

        let candidateRoots = [bundleRoot, localRoot].compactMap { $0 }
        var jsonURLs: [URL] = []
        var seenPaths: Set<String> = []

        for root in candidateRoots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                let name = url.lastPathComponent
                guard name.hasPrefix("MarketUniverse-"), url.pathExtension.lowercased() == "json" else {
                    continue
                }

                guard seenPaths.insert(url.path).inserted else { continue }
                jsonURLs.append(url)
            }
        }

        var records: [MarketUniverseRecord] = []
        var seenRecordIDs: Set<String> = []

        for url in jsonURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: url),
                  let payload = try? decoder.decode([BundledUniverseRecord].self, from: data)
            else {
                continue
            }

            for item in payload {
                let recordKey = item.recordKey
                guard seenRecordIDs.insert(recordKey).inserted else { continue }
                let record = item.makeMarketUniverseRecord()
                records.append(record)
            }
        }

        return records
    }

    nonisolated private static func mergedWithCatalog(_ records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
        var merged: [MarketUniverseRecord] = []
        var seen: Set<String> = []

        for record in records + WealthMarketInstrumentCatalog.additionalUniverseRecords {
            let key = WealthOpportunityLaneRules.laneKey(symbol: record.symbol, market: record.market)
            guard seen.insert(key).inserted else { continue }
            merged.append(record)
        }

        return merged
    }
}

private struct BundledUniverseRecord: Decodable {
    let symbol: String
    let market: String
    let sector: String?
    let companyName: String?

    nonisolated var recordKey: String {
        [
            symbol.uppercased(),
            market.uppercased(),
            (sector?.isEmpty == false ? sector! : "EQUITY").uppercased()
        ].joined(separator: "-")
    }

    nonisolated func makeMarketUniverseRecord() -> MarketUniverseRecord {
        MarketUniverseRecord(
            symbol: symbol.uppercased(),
            name: companyName ?? "",
            assetType: (sector?.isEmpty == false ? sector! : "equity"),
            country: "",
            region: regionName(for: market),
            exchange: market.uppercased(),
            market: market.uppercased(),
            currency: "",
            isin: "",
            provider: "Bundled JSON",
            isActive: true
        )
    }

    nonisolated private func regionName(for market: String) -> String {
        switch market.uppercased() {
        case "NASDAQ", "NYSE", "US", "AMEX", "TSX", "TSXV", "CA":
            return "North America"
        case "B3", "BMV", "BCBA", "BVC", "LIM", "LATAM":
            return "South America"
        case "LSE", "XETRA", "EURONEXT", "SIX", "BME", "MIL", "OMX", "EU":
            return "Europe"
        case "JSE", "EGX", "NSX", "AFRICA":
            return "Africa"
        case "ASX", "NZX", "NSE", "BSE", "TSE", "TWSE", "HKEX", "KRX", "SGX", "SET", "PSE", "HOSE", "APAC", "ASIA", "AU":
            return "Asia"
        case "TADAWUL", "DFM", "ADX", "QE", "KSE", "MSX", "ME":
            return "Middle East"
        case "FX", "CRYPTO", "COM", "GLOBAL":
            return "Global"
        default:
            return "Global"
        }
    }
}

private final class BundleToken {}
