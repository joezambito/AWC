import SwiftUI

extension WealthRootView {
    @ViewBuilder
    var mainContent: some View {
        switch mainTab {
        case .dashboard:
            dashboardSection
        case .activity:
            ActivityView(
                holdings: pendingHoldings,
                opportunities: pendingOpportunities,
                completedOpportunities: completedOpportunities,
                pendingBuyAmountText: WealthFormat.money(portfolio.totalBuyReservedCapital),
                pendingSellAmountText: WealthFormat.money(portfolio.pendingSellReturnCapital),
                summaryTitle: dashboardEventTitle,
                summaryMessage: dashboardEventMessage,
                summaryTint: dashboardEventTint,
                badgeCount: activityBadgeCount,
                moments: desktopMoments,
                onSelectHolding: { selectedHolding = $0 },
                onSelectOpportunity: { selectedOpportunity = $0 }
            )
        case .markets:
            MarketsView()
        case .campaign:
            CampaignView()
        case .system:
            SystemView()
        }
    }
}
