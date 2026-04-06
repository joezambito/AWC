import Foundation

extension WealthMarketUniverseLoader {
    nonisolated static func parseCSV(_ text: String) throws -> [MarketUniverseRecord] {
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedText
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let headerLine = lines.first else {
            return []
        }

        let headers = CSVParser.parseLine(headerLine)
            .enumerated()
            .reduce(into: [String: Int]()) { partial, item in
                let key = item.element
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .replacingOccurrences(of: "\u{feff}", with: "")
                partial[key] = item.offset
            }

        func value(_ fields: [String], for name: String) -> String {
            guard let index = headers[name], fields.indices.contains(index) else { return "" }
            return fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var records: [MarketUniverseRecord] = []
        var seen: Set<String> = []

        for line in lines.dropFirst() {
            let fields = CSVParser.parseLine(line)
            let symbol = value(fields, for: "symbol")
            guard !symbol.isEmpty else { continue }

            let record = MarketUniverseRecord(
                symbol: symbol.uppercased(),
                name: value(fields, for: "name"),
                assetType: normalizedAssetType(value(fields, for: "asset_type")),
                country: value(fields, for: "country"),
                region: value(fields, for: "region"),
                exchange: value(fields, for: "exchange"),
                market: normalizedMarket(
                    value(fields, for: "market"),
                    exchange: value(fields, for: "exchange"),
                    assetType: value(fields, for: "asset_type")
                ),
                currency: value(fields, for: "currency"),
                isin: value(fields, for: "isin"),
                provider: value(fields, for: "provider"),
                isActive: normalizedBool(value(fields, for: "is_active"))
            )

            let recordKey = [
                record.symbol,
                record.market,
                record.assetType,
                record.exchange,
                record.country
            ]
            .joined(separator: "-")
            .uppercased()

            guard seen.insert(recordKey).inserted else { continue }
            records.append(record)
        }

        return records
    }

    nonisolated static func normalizedAssetType(_ value: String) -> String {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return cleaned.isEmpty ? "unknown" : cleaned
    }

    nonisolated static func normalizedBool(_ value: String) -> Bool {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleaned.isEmpty { return true }
        return !["false", "0", "no", "inactive", "delisted"].contains(cleaned)
    }

    nonisolated static func normalizedMarket(_ market: String, exchange: String, assetType: String) -> String {
        let rawExchange = exchange.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let rawMarket = market.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedAssetType = assetType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if let canonicalExchange = canonicalExecutionMarket(forExchange: rawExchange, assetType: normalizedAssetType) {
            return canonicalExchange
        }

        if let canonicalMarket = canonicalExecutionMarket(forMarket: rawMarket) {
            return canonicalMarket
        }

        switch normalizedAssetType {
        case "CURRENCIES":
            return "FX"
        case "CRYPTOS":
            return "CRYPTO"
        case "MONEYMARKETS":
            return "BOND"
        case "INDICES":
            return "GLOBAL"
        default:
            if !rawMarket.isEmpty { return rawMarket }
            if !rawExchange.isEmpty { return rawExchange }
            return "UNKNOWN"
        }
    }

    nonisolated private static func canonicalExecutionMarket(forExchange exchange: String, assetType: String) -> String? {
        switch exchange {
        case "NAS", "NMS", "NGM", "NCM":
            return "NASDAQ"
        case "NYQ", "NYS":
            return "NYSE"
        case "ASE", "PCX", "ARC", "AMEX":
            return "AMEX"
        case "BTS":
            return "CBOE"
        case "PNK", "OTC", "OBB":
            return "OTC"
        case "CCC":
            return "CRYPTO"
        case "CCY":
            return "FX"
        case "TSE":
            return "TSX"
        case "VSE":
            return "TSXV"
        case "ASX", "LSE", "SIX", "OMX", "XETRA", "BME", "BIT", "WSE", "OSE", "BIST", "MOEX",
             "HKEX", "SSE", "SZSE", "KRX", "SGX", "NSE", "BSE", "TWSE", "TPEX", "NZX", "SET", "IDX", "BURSA",
             "PSE", "HOSE", "HNX", "JSE", "KSE", "MSX", "BHB", "DFM", "ADX", "QSE", "TADAWUL",
             "TASE", "EGX", "BMV", "BCBA", "B3", "CSE", "CME", "CBOT", "NYMEX", "COMEX", "ICE":
            return exchange
        case "":
            return assetType == "INDICES" ? nil : nil
        default:
            return nil
        }
    }

    nonisolated private static func canonicalExecutionMarket(forMarket market: String) -> String? {
        switch market {
        case "NASDAQ GLOBAL SELECT", "NASDAQ CAPITAL MARKET", "NASDAQ GLOBAL MARKET", "NASDAQ":
            return "NASDAQ"
        case "NEW YORK STOCK EXCHANGE", "NYSE", "NYSE MKT":
            return "NYSE"
        case "NYSE ARCA":
            return "AMEX"
        case "BATS BZX EXCHANGE":
            return "CBOE"
        case "OTC BULLETIN BOARD", "PINK SHEETS":
            return "OTC"
        case "CRYPTO":
            return "CRYPTO"
        case "FX":
            return "FX"
        case "ASX", "TSX", "TSXV", "LSE", "EURONEXT", "SIX", "OMX", "XETRA", "HKEX", "SSE", "SZSE",
             "KRX", "SGX", "NSE", "BSE", "TWSE", "TPEX", "SET", "IDX", "BURSA", "PSE", "HOSE", "HNX",
             "NZX", "JSE", "DFM", "ADX", "QSE", "TADAWUL", "TASE", "KSE", "MSX", "BHB", "EGX", "BMV",
             "BCBA", "B3", "CME", "CBOT", "NYMEX", "COMEX", "ICE":
            return market
        default:
            return nil
        }
    }
}

private enum CSVParser {
    nonisolated static func parseLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var isInsideQuotes = false

        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                if isInsideQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    current.append("\"")
                    index += 1
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == ",", !isInsideQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }

            index += 1
        }

        fields.append(current)
        return fields
    }
}
