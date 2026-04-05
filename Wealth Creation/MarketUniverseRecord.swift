import Foundation

// MARK: - MarketUniverseRecord
//
// A single record from the global market universe (one tradeable instrument).
// Populated by the universe download / CSV parse; stored and served by
// WealthMarketUniverseStore.

struct MarketUniverseRecord: Identifiable, Codable, Hashable {
    let id: String
    let symbol: String
    let name: String
    let region: String
    let sector: String
    let exchange: String

    // MARK: - Convenience initialiser

    init(
        id: String = UUID().uuidString,
        symbol: String,
        name: String,
        region: String = "",
        sector: String = "",
        exchange: String = ""
    ) {
        self.id       = id
        self.symbol   = symbol
        self.name     = name
        self.region   = region
        self.sector   = sector
        self.exchange = exchange
    }
}
