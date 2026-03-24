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
        let rawMarket = market.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !rawMarket.isEmpty {
            return rawMarket
        }

        let rawExchange = exchange.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !rawExchange.isEmpty {
            return rawExchange
        }

        switch assetType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "currencies":
            return "FX"
        case "cryptos":
            return "CRYPTO"
        case "moneymarkets":
            return "BOND"
        case "indices":
            return "GLOBAL"
        default:
            return "UNKNOWN"
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
