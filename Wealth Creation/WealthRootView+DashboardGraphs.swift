import SwiftUI

extension WealthRootView {
    var screenGlow: some View {
        ZStack {
            RadialGradient(colors: [WealthTheme.cyan.opacity(0.12), .clear], center: .topLeading, startRadius: 20, endRadius: 360)
            RadialGradient(colors: [WealthTheme.purple.opacity(0.14), .clear], center: .bottomTrailing, startRadius: 40, endRadius: 380)
        }
    }

    var desktopGraphDeck: some View {
        WealthDesktopGraphDeckView(
            portfolioTint: wealthPnLTint(portfolio.totalPnL),
            portfolioPoints: portfolioGraphPoints,
            aiFlowPoints: aiFlowPoints,
            reservePoints: reserveGraphPoints
        )
    }

    var portfolioGraphPoints: [Double] {
        let committed = max(displayedCommittedCapital, 1)
        let equity = max(displayedAccountValue, 1)
        let free = max(displayedAvailableCapital, 1)
        let baseline = max(portfolio.capitalBaseline, 1)
        let values = [baseline * 0.94, baseline, committed * 0.92, committed, equity * 0.96, equity, free * 0.9, free]
        let peak = max(values.max() ?? 1, 1)
        return values.map { $0 / peak }
    }

    var aiFlowPoints: [Double] {
        let source = Array(engine.rankedAssets.prefix(8))
        let values = source.isEmpty ? [0.38, 0.42, 0.47, 0.40, 0.51, 0.55] : source.map { max(0.08, 1.0 - (Double($0.aiScore) / 100.0)) }
        return values
    }

    var reserveGraphPoints: [Double] {
        let available = max(displayedAvailableCapital, 1)
        let floor = max(portfolio.floorReserve, 1)
        let reserved = max(displayedBuyReserved, 1)
        let returning = max(displayedSellReturning, 1)
        let values = [available * 0.92, available, floor * 0.88, floor, reserved * 0.94, reserved, returning * 0.9, returning]
        let peak = max(values.max() ?? 1, 1)
        return values.map { $0 / peak }
    }

    var desktopHistoryRail: some View {
        WealthDesktopHistoryRailView(moments: desktopMoments)
    }

    var desktopCommandDeck: some View {
        WealthDesktopCommandDeckView(
            confirmedCount: confirmedHoldings.count,
            pendingCount: activityCount,
            completedCount: recentCompletedCount,
            notificationsReady: notificationStore.isAuthorized
        )
    }

    var desktopMoments: [NotificationMomentViewModel] {
        var items: [NotificationMomentViewModel] = activityMoments.prefix(3).map {
            NotificationMomentViewModel(
                id: $0.id,
                title: $0.title,
                detail: $0.detail,
                timestampText: "ENGINE",
                tint: $0.tint
            )
        }

        items.append(contentsOf: notificationStore.recentMoments.prefix(3).map {
            NotificationMomentViewModel(
                id: $0.id,
                title: $0.title,
                detail: $0.detail,
                timestampText: WealthFormat.ageText($0.timestamp),
                tint: WealthTheme.cyan
            )
        })

        return Array(items.prefix(5))
    }
}
