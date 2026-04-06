import SwiftUI

extension WealthRootView {
    private var displayedDashboardSnapshot: WealthEngineStore.DashboardSnapshot? {
        engine.dashboardSnapshot
    }

    private var fallbackDashboardMoney: WealthPortfolioRuntimeMoneySnapshot {
        portfolio.runtimeMoneySnapshot
    }

    var displayedCashBalance: Double {
        displayedDashboardSnapshot?.cashBalance ?? fallbackDashboardMoney.cashBalance
    }

    var displayedAvailableCapital: Double {
        displayedDashboardSnapshot?.availableCapital ?? fallbackDashboardMoney.availableCapital
    }

    var displayedCommittedCapital: Double {
        displayedDashboardSnapshot?.committedCapital ?? fallbackDashboardMoney.committedCapital
    }

    var displayedHoldingsValue: Double {
        displayedDashboardSnapshot?.holdingsValue ?? fallbackDashboardMoney.holdingsValue
    }

    var displayedAccountValue: Double {
        displayedDashboardSnapshot?.accountValue ?? fallbackDashboardMoney.accountValue
    }

    var displayedBuyReserved: Double {
        displayedDashboardSnapshot?.buyReserved ?? fallbackDashboardMoney.buyReserved
    }

    var displayedSellReturning: Double {
        displayedDashboardSnapshot?.sellReturning ?? fallbackDashboardMoney.sellReturning
    }

    var displayedTotalPnL: Double {
        displayedDashboardSnapshot?.totalPnL ?? fallbackDashboardMoney.totalPnL
    }

    var displayedPnLPercent: Double {
        let invested = max(displayedCommittedCapital, 0)
        guard invested > 0 else { return 0 }
        return (displayedTotalPnL / invested) * 100
    }

    var dashboardAvailableCapitalText: String {
        WealthFormat.money(displayedAvailableCapital)
    }

    var dashboardCashBalanceText: String {
        WealthFormat.money(displayedCashBalance)
    }

    var dashboardCommittedCapitalText: String {
        WealthFormat.money(displayedCommittedCapital)
    }

    var dashboardHoldingsValueText: String {
        WealthFormat.money(displayedHoldingsValue)
    }

    var dashboardAccountValueText: String {
        WealthFormat.money(displayedAccountValue)
    }

    var dashboardBuyReservedText: String {
        WealthFormat.money(displayedBuyReserved)
    }

    var dashboardSellReturningText: String {
        WealthFormat.money(displayedSellReturning)
    }

    var dashboardTotalPnLText: String {
        wealthPnLText(displayedTotalPnL)
    }

    var dashboardTotalPnLTint: Color {
        wealthPnLTint(displayedTotalPnL)
    }

    var dashboardPnLPercentText: String {
        wealthPercentMoveText(displayedPnLPercent)
    }

    var dashboardPnLPercentTint: Color {
        wealthPercentMoveTint(displayedPnLPercent)
    }
}
