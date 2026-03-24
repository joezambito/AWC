import SwiftUI
import Combine

@MainActor
final class WealthBrokerStore: ObservableObject {
    static let shared = WealthBrokerStore()

    static let defaultPaperBalance: Double = 0
    static let defaultLiveBalance: Double = 0

    private enum StorageKey {
        static let primaryBroker = "awc_broker_primary_name"
        static let lowestFeeFirst = "awc_broker_lowest_fee_first"
        static let smartRouting = "awc_broker_smart_routing"
        static let accountID = "awc_broker_ibkr_account_id"
        static let paperBalance = "awc_broker_ibkr_paper_balance"
        static let liveBalance = "awc_broker_ibkr_live_balance"
        static let paperEnabled = "awc_broker_paper_enabled"
        static let liveEnabled = "awc_broker_live_enabled"
    }

    @Published var selectedBroker: BrokerProfile
    @Published var lowestFeeFirst: Bool
    @Published var smartRouting: Bool
    @Published var ibkrAccountID: String
    @Published var ibkrPaperBalance: Double
    @Published var ibkrLiveBalance: Double
    @Published var paperTradingEnabled: Bool
    @Published var liveTradingEnabled: Bool
    @Published var searchQuery: String
    @Published var lastBrokerFailureAt: Date?
    @Published var lastBrokerFailureReason: String
    @Published var brokerResults: [BrokerProfile]

    let registry: [BrokerProfile]
    private let defaults = UserDefaults.standard

    private init() {
        let initialRegistry = [
            BrokerProfile(name: "IBKR", feeLabel: "LOW COST", mode: "Paper Execution", safety: "Trusted", trusted: true, feeScore: 1),
            BrokerProfile(name: "CMC", feeLabel: "LOW COST", mode: "Manual Confirm", safety: "Trusted", trusted: true, feeScore: 2),
            BrokerProfile(name: "Saxo", feeLabel: "MID COST", mode: "Manual Confirm", safety: "Trusted", trusted: true, feeScore: 3),
            BrokerProfile(name: "Stake", feeLabel: "MID COST", mode: "Watchlist Route", safety: "Connected", trusted: false, feeScore: 4)
        ]

        registry = initialRegistry
        let storedName = defaults.string(forKey: StorageKey.primaryBroker) ?? "IBKR"

        selectedBroker = initialRegistry.first(where: { $0.name == storedName }) ?? initialRegistry[0]
        lowestFeeFirst = defaults.object(forKey: StorageKey.lowestFeeFirst) as? Bool ?? true
        smartRouting = defaults.object(forKey: StorageKey.smartRouting) as? Bool ?? true
        ibkrAccountID = defaults.string(forKey: StorageKey.accountID) ?? ""
        ibkrPaperBalance = defaults.object(forKey: StorageKey.paperBalance) as? Double ?? Self.defaultPaperBalance
        ibkrLiveBalance = defaults.object(forKey: StorageKey.liveBalance) as? Double ?? Self.defaultLiveBalance
        paperTradingEnabled = defaults.object(forKey: StorageKey.paperEnabled) as? Bool ?? true
        liveTradingEnabled = defaults.object(forKey: StorageKey.liveEnabled) as? Bool ?? false
        searchQuery = ""
        lastBrokerFailureAt = nil
        lastBrokerFailureReason = ""
        brokerResults = []
    }

    func select(_ broker: BrokerProfile) {
        selectedBroker = broker
        defaults.set(broker.name, forKey: StorageKey.primaryBroker)
    }

    func persistRouting() {
        defaults.set(lowestFeeFirst, forKey: StorageKey.lowestFeeFirst)
        defaults.set(smartRouting, forKey: StorageKey.smartRouting)
        defaults.set(ibkrAccountID, forKey: StorageKey.accountID)
        defaults.set(ibkrPaperBalance, forKey: StorageKey.paperBalance)
        defaults.set(ibkrLiveBalance, forKey: StorageKey.liveBalance)
        defaults.set(paperTradingEnabled, forKey: StorageKey.paperEnabled)
        defaults.set(liveTradingEnabled, forKey: StorageKey.liveEnabled)
    }

    func resetBalancesToZero() {
        ibkrPaperBalance = 0
        ibkrLiveBalance = 0
        persistRouting()
    }
}
