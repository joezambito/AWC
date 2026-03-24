import Foundation

@MainActor
final class WealthWorldMarketBulkQuotePass {
    static let shared = WealthWorldMarketBulkQuotePass()

    private let batchSize = 60
    private let batchIntervalNanoseconds: UInt64 = 1_200_000_000

    private var contracts: [WealthIBKRContract] = []
    private var contractKeys: [WealthBrokerQuoteKey] = []
    private var delayedQuotes = true
    private var cursor = 0
    private var task: Task<Void, Never>?

    private init() {}

    func start(
        records: [MarketUniverseRecord],
        quotes: [WealthBrokerQuoteKey: WealthBrokerQuote],
        delayedQuotes: Bool
    ) {
        let nextContracts = prioritizedContracts(from: records, quotes: quotes)
        let nextKeys = nextContracts.map(\.key)

        guard !nextContracts.isEmpty else {
            stop()
            return
        }

        if nextKeys == contractKeys, self.delayedQuotes == delayedQuotes, task != nil {
            return
        }

        task?.cancel()
        contracts = nextContracts
        contractKeys = nextKeys
        self.delayedQuotes = delayedQuotes
        cursor = 0

        task = Task { @MainActor [weak self] in
            await self?.run()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        contracts = []
        contractKeys = []
        cursor = 0
    }

    private func prioritizedContracts(
        from records: [MarketUniverseRecord],
        quotes: [WealthBrokerQuoteKey: WealthBrokerQuote]
    ) -> [WealthIBKRContract] {
        let now = Date()
        var seen: Set<WealthBrokerQuoteKey> = []

        return records
            .compactMap(WealthIBKRInstrumentResolver.supportedContract(for:))
            .filter { seen.insert($0.key).inserted }
            .sorted { lhs, rhs in
                let leftAge = quotes[lhs.key].map { now.timeIntervalSince($0.timestamp) } ?? .infinity
                let rightAge = quotes[rhs.key].map { now.timeIntervalSince($0.timestamp) } ?? .infinity

                if leftAge != rightAge {
                    return leftAge > rightAge
                }

                if lhs.key.market != rhs.key.market {
                    return lhs.key.market < rhs.key.market
                }

                return lhs.key.symbol < rhs.key.symbol
            }
    }

    private func nextBatch() -> [WealthIBKRContract] {
        guard !contracts.isEmpty else { return [] }
        guard cursor < contracts.count else { return [] }

        let start = cursor
        let end = min(start + batchSize, contracts.count)
        let batch = Array(contracts[start..<end])
        cursor = end
        return batch
    }

    private func run() async {
        while !Task.isCancelled {
            let batch = nextBatch()
            guard !batch.isEmpty else {
                task = nil
                return
            }

            WealthIBKRBridge.shared.subscribe(to: batch, delayedQuotes: delayedQuotes)

            do {
                try await Task.sleep(nanoseconds: batchIntervalNanoseconds)
            } catch {
                return
            }
        }
    }
}
