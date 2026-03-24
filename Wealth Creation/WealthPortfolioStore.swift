import Combine
import Foundation
import SwiftUI

@MainActor
final class WealthPortfolioStore: ObservableObject {
    enum StorageKey {
        static let externalDeposits = "awc_portfolio_external_deposits"
        static let protectedBaseCapital = "awc_portfolio_protected_base_capital"
        static let earnedProfit = "awc_portfolio_earned_profit"
        static let dailyProfit = "awc_portfolio_daily_profit"
        static let reservedOrderCapital = "awc_portfolio_reserved_order_capital"
        static let holdings = "awc_portfolio_holdings"
        static let queuedOpportunities = "awc_portfolio_queued_opportunities"
        static let completedActivity = "awc_portfolio_completed_activity"
        static let saleGates = "awc_portfolio_sale_gates"
    }

    static let shared = WealthPortfolioStore()

    @Published var externalDeposits: Double { didSet { persistMetrics() } }
    @Published var protectedBaseCapital: Double { didSet { persistMetrics() } }
    @Published var earnedProfit: Double { didSet { persistMetrics() } }
    @Published var dailyProfit: Double { didSet { persistMetrics() } }
    @Published var reservedOrderCapital: Double { didSet { persistMetrics() } }
    @Published var holdings: [Holding] { didSet { persistHoldings() } }
    @Published var queuedOpportunities: [Opportunity] { didSet { persistQueuedOpportunities() } }
    @Published var completedActivity: [Opportunity] { didSet { persistCompletedActivity() } }
    @Published var saleGates: [String: PersistedSaleGate] { didSet { persistSaleGates() } }
    @Published var lastRefresh: Date?

    let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.purgeLegacyPortfolioStorage(from: defaults)

        let restoredHoldings = Self.loadPersistedHoldings(from: defaults)
        let restoredQueued = Self.restoreQueuedOpportunities(from: defaults)
        let restoredCompleted = Self.loadPersistedCompletedActivity(from: defaults)

        externalDeposits = defaults.object(forKey: StorageKey.externalDeposits) as? Double ?? 0
        protectedBaseCapital = defaults.object(forKey: StorageKey.protectedBaseCapital) as? Double ?? 0
        earnedProfit = defaults.object(forKey: StorageKey.earnedProfit) as? Double ?? 0
        dailyProfit = defaults.object(forKey: StorageKey.dailyProfit) as? Double ?? 0
        holdings = restoredHoldings
        queuedOpportunities = restoredQueued
        completedActivity = restoredCompleted.isEmpty
            ? Self.seedCompletedActivity(from: restoredHoldings)
            : Self.prunedCompletedActivity(restoredCompleted)
        reservedOrderCapital = Self.restoredReservedOrderCapital(
            holdings: restoredHoldings,
            queuedOpportunities: restoredQueued
        )
        saleGates = Self.loadPersistedSaleGates(from: defaults)
        lastRefresh = Date().addingTimeInterval(-90)

        persistMetrics()
    }

    func resetAccountToZero() {
        externalDeposits = 0
        protectedBaseCapital = 0
        earnedProfit = 0
        dailyProfit = 0
        reservedOrderCapital = 0
        holdings = []
        queuedOpportunities = []
        completedActivity = []
        saleGates = [:]
        lastRefresh = Date()

        persistMetrics()
        persistHoldings()
        persistQueuedOpportunities()
        persistCompletedActivity()
        persistSaleGates()
    }
}
