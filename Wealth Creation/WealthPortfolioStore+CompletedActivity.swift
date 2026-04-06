import Foundation

extension WealthPortfolioStore {
    static func recalculatedProfitMetrics(
        from completedActivity: [Opportunity],
        fallbackEarnedProfit: Double,
        fallbackDailyProfit: Double,
        now: Date = .now
    ) -> (earnedProfit: Double, dailyProfit: Double) {
        guard !completedActivity.isEmpty else {
            return (fallbackEarnedProfit, fallbackDailyProfit)
        }

        let calendar = Calendar.autoupdatingCurrent
        let earnedProfit = completedActivity.reduce(0) { running, opportunity in
            running + opportunity.actualRealizedNetProfit
        }
        let dailyProfit = completedActivity.reduce(0) { running, opportunity in
            guard let completedAt = opportunity.completedAt,
                  calendar.isDate(completedAt, inSameDayAs: now) else {
                return running
            }
            return running + opportunity.actualRealizedNetProfit
        }

        return (earnedProfit, dailyProfit)
    }

    func refreshProfitMetricsFromCompletedActivity(now: Date = .now) {
        let metrics = Self.recalculatedProfitMetrics(
            from: completedActivity,
            fallbackEarnedProfit: earnedProfit,
            fallbackDailyProfit: dailyProfit,
            now: now
        )
        earnedProfit = metrics.earnedProfit
        dailyProfit = metrics.dailyProfit
    }

    static func seedCompletedActivity(from holdings: [Holding], now: Date = .now) -> [Opportunity] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        let seeded = holdings
            .filter { holding in
                guard holding.orderState == .filled else { return false }
                let completedAt = holding.filledAt ?? holding.lastRefreshTimestamp
                return completedAt >= cutoff
            }
            .sorted { lhs, rhs in
                let leftCompletedAt = lhs.filledAt ?? lhs.lastRefreshTimestamp
                let rightCompletedAt = rhs.filledAt ?? rhs.lastRefreshTimestamp
                return leftCompletedAt > rightCompletedAt
            }
            .map { completedBuySnapshot(from: $0, completedAt: $0.filledAt ?? $0.lastRefreshTimestamp) }

        return Array(seeded.prefix(12))
    }

    func recordCompletedActivity(_ opportunity: Opportunity, now: Date = .now) {
        let snapshot = opportunity.withLastRefresh(now)

        completedActivity.removeAll {
            $0.symbol == snapshot.symbol &&
            $0.commandText == snapshot.commandText &&
            abs($0.lastRefreshTimestamp.timeIntervalSince(snapshot.lastRefreshTimestamp)) < 1
        }

        completedActivity.insert(snapshot, at: 0)
        completedActivity = Self.prunedCompletedActivity(completedActivity, now: now)
        refreshProfitMetricsFromCompletedActivity(now: now)
    }
}
