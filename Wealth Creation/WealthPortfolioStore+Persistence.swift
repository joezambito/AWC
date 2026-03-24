import Foundation

extension WealthPortfolioStore {
    static let migrationKey = "awc_portfolio_storage_migration_version"
    static let migrationVersion = 1

    func persistMetrics() {
        defaults.set(externalDeposits, forKey: StorageKey.externalDeposits)
        defaults.set(protectedBaseCapital, forKey: StorageKey.protectedBaseCapital)
        defaults.set(earnedProfit, forKey: StorageKey.earnedProfit)
        defaults.set(dailyProfit, forKey: StorageKey.dailyProfit)
        defaults.set(reservedOrderCapital, forKey: StorageKey.reservedOrderCapital)
    }

    func persistHoldings() {
        let payload = holdings.map(Self.persistedHolding(from:))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: StorageKey.holdings)
    }

    func persistQueuedOpportunities() {
        let payload = queuedOpportunities.map(Self.persistedOpportunity(from:))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: StorageKey.queuedOpportunities)
    }

    func persistCompletedActivity() {
        let payload = completedActivity.map(Self.persistedOpportunity(from:))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: StorageKey.completedActivity)
    }

    func persistSaleGates() {
        let payload = Array(saleGates.values)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: StorageKey.saleGates)
    }
}
