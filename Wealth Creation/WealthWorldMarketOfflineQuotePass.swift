import Foundation

@MainActor
final class WealthWorldMarketOfflineQuotePass {
    static let shared = WealthWorldMarketOfflineQuotePass()

    private let batchSize = 120
    private let batchIntervalNanoseconds: UInt64 = 2_000_000_000

    private var records: [MarketUniverseRecord] = []
    private var recordKeys: [String] = []
    private var cursor = 0
    private var task: Task<Void, Never>?

    private init() {}

    func start(records: [MarketUniverseRecord]) {
        var seen: Set<String> = []
        let orderedRecords = records.filter { seen.insert($0.id).inserted }
        let nextKeys = orderedRecords.map(\.id)

        guard !orderedRecords.isEmpty else {
            stop()
            return
        }

        if nextKeys == recordKeys, task != nil {
            return
        }

        task?.cancel()
        self.records = orderedRecords
        recordKeys = nextKeys
        cursor = 0

        task = Task { @MainActor [weak self] in
            await self?.run()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        records = []
        recordKeys = []
        cursor = 0
    }

    private func run() async {
        while !Task.isCancelled {
            let batch = nextBatch()
            guard !batch.isEmpty else { return }

            let now = Date()
            for record in batch {
                WealthBrokerQuoteStore.shared.ingest(makeQuote(for: record, at: now))
            }

            do {
                try await Task.sleep(nanoseconds: batchIntervalNanoseconds)
            } catch {
                return
            }
        }
    }

    private func nextBatch() -> [MarketUniverseRecord] {
        guard !records.isEmpty else { return [] }

        let start = cursor
        let end = min(start + batchSize, records.count)
        let batch = Array(records[start..<end])
        cursor = end >= records.count ? 0 : end
        return batch
    }

    private func makeQuote(for record: MarketUniverseRecord, at now: Date) -> WealthBrokerQuote {
        let key = WealthBrokerQuoteKey(symbol: record.symbol, market: record.market)
        let minute = Int(now.timeIntervalSince1970 / 60)
        let base = anchorPrice(for: record)
        let drift = intradayDrift(symbol: record.symbol, market: record.market, minute: minute)
        let priorDrift = intradayDrift(symbol: record.symbol, market: record.market, minute: minute - 1)
        let price = roundedPrice(base * (1 + drift))
        let close = roundedPrice(base * (1 + priorDrift))
        let spread = max(price * 0.0008, 0.01)
        let currency = WealthIBKRContractMapper.contract(for: record)?.currency ?? fallbackCurrency(for: record)

        return WealthBrokerQuote(
            key: key,
            price: price,
            close: close,
            bid: roundedPrice(max(0.01, price - spread)),
            ask: roundedPrice(price + spread),
            bidSize: 0,
            askSize: 0,
            lastSize: 0,
            currency: currency,
            timestamp: now,
            isDelayed: true
        )
    }

    private func anchorPrice(for record: MarketUniverseRecord) -> Double {
        let unit = normalizedHash("\(record.symbol)-\(record.market)-anchor")
        let symbol = record.symbol

        if symbol.allSatisfy(\.isNumber) {
            return 12 + (unit * 180)
        }

        switch record.market.uppercased() {
        case "NASDAQ", "NYSE", "AMEX", "OTC":
            return 4 + (unit * 280)
        case "ASX", "TSX", "LSE", "EURONEXT", "XETRA", "HKEX", "SGX":
            return 3 + (unit * 220)
        case "NSE", "BSE", "KRX", "TWSE", "SET", "IDX", "BURSA":
            return 2 + (unit * 160)
        default:
            return 2 + (unit * 140)
        }
    }

    private func intradayDrift(symbol: String, market: String, minute: Int) -> Double {
        let fast = normalizedHash("\(symbol)-\(market)-\(minute)") - 0.5
        let slow = normalizedHash("\(market)-\(minute / 7)") - 0.5
        return (fast * 0.028) + (slow * 0.014)
    }

    private func fallbackCurrency(for record: MarketUniverseRecord) -> String {
        let trimmed = record.currency.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "USD" : trimmed.uppercased()
    }

    private func normalizedHash(_ value: String) -> Double {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Double(hash % 10_000) / 10_000.0
    }

    private func roundedPrice(_ value: Double) -> Double {
        switch value {
        case ..<1:
            return (value * 10_000).rounded() / 10_000
        case ..<500:
            return (value * 100).rounded() / 100
        default:
            return (value * 10).rounded() / 10
        }
    }
}
