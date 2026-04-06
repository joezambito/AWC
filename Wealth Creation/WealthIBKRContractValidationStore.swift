import Foundation
import Combine

@MainActor
final class WealthIBKRContractValidationStore: ObservableObject {
    static let shared = WealthIBKRContractValidationStore()

    private enum StorageKey {
        static let invalidSymbolKeys = "awc_ibkr_invalid_symbol_keys_v1"
        static let resolvedContracts = "awc_ibkr_resolved_contracts_v1"
    }

    private struct StoredContract: Codable {
        let symbol: String
        let market: String
        let secType: String
        let exchange: String
        let primaryExchange: String
        let currency: String
        let localSymbol: String
        let tradingClass: String
    }

    @Published private(set) var validSymbols: [WealthBrokerQuoteKey] = []
    @Published private(set) var invalidSymbols: [WealthBrokerQuoteKey] = []
    @Published private(set) var reportRows: [WealthIBKRInstrumentResolution] = []

    private let defaults = UserDefaults.standard
    private var resolvedContractsByKey: [WealthBrokerQuoteKey: WealthIBKRContract] = [:]

    private init() {
        invalidSymbols = persistedInvalidKeys()
        resolvedContractsByKey = persistedResolvedContracts()
        validSymbols = resolvedContractsByKey.keys.sorted {
            if $0.market != $1.market { return $0.market < $1.market }
            return $0.symbol < $1.symbol
        }
    }

    func cleanWorldMarketRecords(_ records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
        let knownInvalidKeySet = Set(invalidSymbols)
        guard !knownInvalidKeySet.isEmpty else { return records }
        return records.filter { !knownInvalidKeySet.contains(WealthBrokerQuoteKey(symbol: $0.symbol, market: $0.market)) }
    }

    func refreshReportRows(from records: [MarketUniverseRecord]) {
        reportRows = WealthIBKRInstrumentResolver.reportRows(for: records)
    }

    func shouldRetry(_ key: WealthBrokerQuoteKey) -> Bool {
        !invalidSymbols.contains(key)
    }

    func resolvedContract(for key: WealthBrokerQuoteKey) -> WealthIBKRContract? {
        resolvedContractsByKey[key]
    }

    func noteResolvedContract(_ contract: WealthIBKRContract) {
        resolvedContractsByKey[contract.key] = contract
        validSymbols = resolvedContractsByKey.keys.sorted {
            if $0.market != $1.market { return $0.market < $1.market }
            return $0.symbol < $1.symbol
        }
        invalidSymbols.removeAll { $0 == contract.key }
        persistResolvedContracts()
        persistInvalidKeys(invalidSymbols)
    }

    func markInvalid(_ key: WealthBrokerQuoteKey) {
        guard !invalidSymbols.contains(key) else { return }
        invalidSymbols.append(key)
        invalidSymbols.sort {
            if $0.market != $1.market { return $0.market < $1.market }
            return $0.symbol < $1.symbol
        }
        resolvedContractsByKey[key] = nil
        validSymbols.removeAll { $0 == key }
        persistInvalidKeys(invalidSymbols)
        persistResolvedContracts()
    }

    func reportCSV() -> String {
        let header = "symbol,status,resolved_secType,resolved_exchange,currency,action_taken"
        let rows = reportRows.map { row in
            [
                row.key.symbol,
                row.status.rawValue,
                row.resolvedSecType ?? "",
                row.resolvedExchange ?? "",
                row.currency ?? "",
                row.actionTaken
            ]
            .map(csvField)
            .joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    private func persistedInvalidKeys() -> [WealthBrokerQuoteKey] {
        guard let stored = defaults.array(forKey: StorageKey.invalidSymbolKeys) as? [String] else { return [] }
        return stored.compactMap { item in
            let pieces = item.split(separator: "|", omittingEmptySubsequences: false)
            guard pieces.count == 2 else { return nil }
            return WealthBrokerQuoteKey(symbol: String(pieces[0]), market: String(pieces[1]))
        }
    }

    private func persistInvalidKeys(_ keys: [WealthBrokerQuoteKey]) {
        let encoded = keys.map { "\($0.symbol)|\($0.market)" }
        defaults.set(encoded, forKey: StorageKey.invalidSymbolKeys)
    }

    private func persistedResolvedContracts() -> [WealthBrokerQuoteKey: WealthIBKRContract] {
        guard let data = defaults.data(forKey: StorageKey.resolvedContracts) else { return [:] }
        guard let stored = try? JSONDecoder().decode([StoredContract].self, from: data) else { return [:] }
        return stored.reduce(into: [:]) { partial, item in
            let key = WealthBrokerQuoteKey(symbol: item.symbol, market: item.market)
            partial[key] = WealthIBKRContract(
                key: key,
                symbol: item.symbol,
                secType: item.secType,
                exchange: item.exchange,
                primaryExchange: item.primaryExchange,
                currency: item.currency,
                localSymbol: item.localSymbol,
                tradingClass: item.tradingClass
            )
        }
    }

    private func persistResolvedContracts() {
        let payload = resolvedContractsByKey.values
            .sorted {
                if $0.key.market != $1.key.market { return $0.key.market < $1.key.market }
                return $0.key.symbol < $1.key.symbol
            }
            .map {
                StoredContract(
                    symbol: $0.key.symbol,
                    market: $0.key.market,
                    secType: $0.secType,
                    exchange: $0.exchange,
                    primaryExchange: $0.primaryExchange,
                    currency: $0.currency,
                    localSymbol: $0.localSymbol,
                    tradingClass: $0.tradingClass
                )
            }
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: StorageKey.resolvedContracts)
        }
    }

    private func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
