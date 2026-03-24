import SwiftUI

struct ActivityView: View {
    let holdings: [Holding]
    let opportunities: [Opportunity]
    let completedOpportunities: [Opportunity]
    let pendingBuyAmountText: String
    let pendingSellAmountText: String
    let summaryTitle: String
    let summaryMessage: String
    let summaryTint: Color
    let badgeCount: Int
    let moments: [NotificationMomentViewModel]
    let onSelectHolding: (Holding) -> Void
    let onSelectOpportunity: (Opportunity) -> Void

    private var activeCount: Int { holdings.count + opportunities.count }
    private var recheckCount: Int {
        opportunities.filter { $0.sessionState == .recheckAtOpen || $0.sessionState == .waitingForOpen }.count
    }
    private var completedCount: Int { min(completedOpportunities.count, 3) }

    private var hasDesktopLayout: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }

    var body: some View {
        VStack(spacing: 6) {
            if hasDesktopLayout {
                sectionShell(
                    title: "ACTIVITY",
                    subtitle: "Pending orders and latest data confirmation checks",
                    trailing: "\(activeCount) ACTIVE"
                )
                ActivitySummaryBanner(
                    title: summaryTitle,
                    message: summaryMessage,
                    tint: summaryTint,
                    badgeCount: badgeCount,
                    moments: moments
                )
            }

            summaryCards

            if opportunities.isEmpty && holdings.isEmpty && completedOpportunities.isEmpty {
                emptyState
            } else {
                if !opportunities.isEmpty {
                    BrainPicksView(opportunities: opportunities) { _ in }
                }
                if !holdings.isEmpty {
                    PendingHoldingSection(holdings: holdings)
                }
                if !completedOpportunities.isEmpty {
                    RecentCompletedSection(opportunities: completedOpportunities)
                }
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 6) {
            compactSummaryCard(title: "Buy Reserved", value: pendingBuyAmountText, tint: WealthTheme.cyan)
            compactSummaryCard(title: "Sell Returning", value: pendingSellAmountText, tint: WealthTheme.purple)
            compactSummaryCard(title: "Pending Buys", value: "\(opportunities.count)", tint: WealthTheme.gold)
            compactSummaryCard(title: "Pending Sells", value: "\(holdings.count)", tint: Color.white.opacity(0.88))
            compactSummaryCard(title: "Recheck", value: "\(recheckCount)", tint: WealthTheme.orange)
            compactSummaryCard(title: "Completed", value: "\(completedCount)", tint: WealthTheme.cyan)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("NO ACTIVE ORDERS")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text("New buys and sells will appear here until the latest confirmation checks complete.")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(cardShell(cornerRadius: 20))
    }
}
