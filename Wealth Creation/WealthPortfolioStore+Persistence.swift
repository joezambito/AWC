import Foundation

extension WealthPortfolioStore {
    static let migrationKey = "awc_portfolio_storage_migration_version"
    static let migrationVersion = 2
    private static let completedActivityFileName = "portfolio_completed_activity_v1.json"

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
        Self.persistCompletedActivityData(data)
        defaults.removeObject(forKey: StorageKey.completedActivity)
    }

    func persistSaleGates() {
        let payload = Array(saleGates.values)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: StorageKey.saleGates)
    }

    static func loadPersistedCompletedActivityData(from defaults: UserDefaults) -> Data? {
        if let fileURL = completedActivityFileURL(),
           let fileData = try? Data(contentsOf: fileURL) {
            defaults.removeObject(forKey: StorageKey.completedActivity)
            return fileData
        }

        guard let stored = defaults.data(forKey: StorageKey.completedActivity) else {
            return nil
        }

        persistCompletedActivityData(stored)
        defaults.removeObject(forKey: StorageKey.completedActivity)
        return stored
    }

    static func persistCompletedActivityData(_ data: Data) {
        guard let fileURL = completedActivityFileURL(createIfNeeded: true) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    static func completedActivityFileURL(createIfNeeded: Bool = false) -> URL? {
        guard let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: createIfNeeded
        ) else {
            return nil
        }

        return baseURL
            .appendingPathComponent("WealthCreationCache", isDirectory: true)
            .appendingPathComponent(completedActivityFileName)
    }
}
