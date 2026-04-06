import Foundation

struct WealthPortfolioRuntimeMoneySnapshot {
    let cashBalance: Double
    let availableCapital: Double
    let committedCapital: Double
    let holdingsValue: Double
    let accountValue: Double
    let buyReserved: Double
    let sellReturning: Double
    let totalPnL: Double
    let holdingsCount: Int
    let positionsCount: Int
}

enum WealthMoneyTraceLogger {
    static func log(
        stage: String,
        snapshot: WealthPortfolioRuntimeMoneySnapshot,
        marketCandidates: Int
    ) {
#if DEBUG
        print(
            "[MoneyTrace] stage=\(stage) holdings=\(snapshot.holdingsCount) " +
            "positions=\(snapshot.positionsCount) cash=\(snapshot.cashBalance) " +
            "available=\(snapshot.availableCapital) invested=\(snapshot.committedCapital) " +
            "account=\(snapshot.accountValue) pnl=\(snapshot.totalPnL) " +
            "market_candidates=\(marketCandidates)"
        )
#endif
    }
}

extension WealthPortfolioRuntimeMoneySnapshot {
    init(snapshot: WealthEngineStore.DashboardSnapshot, holdingsCount: Int, positionsCount: Int) {
        self.cashBalance = snapshot.cashBalance
        self.availableCapital = snapshot.availableCapital
        self.committedCapital = snapshot.committedCapital
        self.holdingsValue = snapshot.holdingsValue
        self.accountValue = snapshot.accountValue
        self.buyReserved = snapshot.buyReserved
        self.sellReturning = snapshot.sellReturning
        self.totalPnL = snapshot.totalPnL
        self.holdingsCount = holdingsCount
        self.positionsCount = positionsCount
    }
}
