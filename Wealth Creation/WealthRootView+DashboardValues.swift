import SwiftUI

extension WealthRootView {
    private var displayedDashboardSnapshot: WealthEngineStore.DashboardSnapshot? {
        engine.dashboardSnapshot
    }

    var displayedCashBalance: Double {
        displayedDashboardSnapshot?.availableCapital ?? portfolio.availableCapital
    }

    var displayedAvailableCapital: Double {
        displayedDashboardSnapshot?.availableCapital ?? portfolio.availableCapital
    }

    var displayedCommittedCapital: Double {
        displayedDashboardSnapshot?.committedCapital ?? portfolio.committedCapital
    }

    var displayedHoldingsValue: Double {
        displayedDashboardSnapshot?.holdingsValue ?? portfolio.holdingsValue
    }

    var displayedAccountValue: Double {
        displayedDashboardSnapshot?.accountValue ?? portfolio.totalAccountAmount
    }

    var displayedBuyReserved: Double {
        displayedDashboardSnapshot?.buyReserved ?? portfolio.totalBuyReservedCapital
    }

    var displayedSellReturning: Double {
        displayedDashboardSnapshot?.sellReturning ?? portfolio.pendingSellReturnCapital
    }

    var displayedTotalPnL: Double {
        displayedDashboardSnapshot?.totalPnL ?? portfolio.totalPnL
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
}
