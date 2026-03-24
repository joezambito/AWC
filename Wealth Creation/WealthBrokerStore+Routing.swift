import Foundation

@MainActor
extension WealthBrokerStore {
    func updateSearchResults() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            brokerResults = []
            return
        }

        brokerResults = registry
            .filter { $0.trusted }
            .filter { profile in
                profile.name.localizedCaseInsensitiveContains(trimmed) ||
                profile.mode.localizedCaseInsensitiveContains(trimmed)
            }
            .sorted(by: preferredOrder)

        if let best = brokerResults.first {
            select(best)
        }
    }

    func pinnedBroker() -> BrokerProfile {
        registry.first(where: { $0.name == "IBKR" }) ?? selectedBroker
    }

    var availableBrokers: [BrokerProfile] {
        registry
    }

    var currentRouteLabel: String {
        "\(selectedBroker.name) · \(selectedBroker.feeLabel)"
    }

    func debitExecutionBalance(_ amount: Double) {
        let value = max(0, amount)
        guard executionEnabled, value > 0 else { return }

        if liveExecutionArmed {
            ibkrLiveBalance = max(0, ibkrLiveBalance - value)
        } else {
            ibkrPaperBalance = max(0, ibkrPaperBalance - value)
        }

        persistRouting()
    }

    func creditExecutionBalance(_ amount: Double) {
        let value = max(0, amount)
        guard executionEnabled, value > 0 else { return }

        if liveExecutionArmed {
            ibkrLiveBalance += value
        } else {
            ibkrPaperBalance += value
        }

        persistRouting()
    }

    private func preferredOrder(lhs: BrokerProfile, rhs: BrokerProfile) -> Bool {
        if lhs.trusted != rhs.trusted {
            return lhs.trusted && !rhs.trusted
        }
        if lowestFeeFirst && lhs.feeScore != rhs.feeScore {
            return lhs.feeScore < rhs.feeScore
        }
        return lhs.name < rhs.name
    }
}
