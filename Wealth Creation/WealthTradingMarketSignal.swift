import Foundation

struct MarketSignal: Identifiable, Hashable {
    let id: UUID
    let symbol: String
    let market: String
    let sector: String
    let theme: String

    init(
        id: UUID = UUID(),
        symbol: String,
        market: String,
        sector: String,
        theme: String
    ) {
        self.id = id
        self.symbol = symbol
        self.market = market
        self.sector = sector
        self.theme = theme
    }
}
