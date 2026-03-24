import SwiftUI

extension WealthRootView {
    var phoneSafeRoot: some View {
        NavigationStack {
            ZStack {
                WealthTheme.background
                    .overlay(screenGlow)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        if mainTab == .dashboard {
                            phoneSafeHeader
                        }

                        phoneSafeMainContent

                        Color.clear
                            .frame(height: 84)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                }
                .id("phone-tab-\(mainTab.rawValue)")
            }
            .safeAreaInset(edge: .bottom) {
                bottomDock
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .background(Color.black.opacity(0.001))
            }
            .fullScreenCover(item: $selectedHolding) { holding in
                HoldingDetailView(holding: holding)
            }
            .fullScreenCover(item: $selectedOpportunity) { opportunity in
                OpportunityDetailView(opportunity: opportunity)
            }
        }
    }

    var phoneSafeHeader: some View {
        WealthPhoneSafeHeaderView(
            lastRefreshText: WealthFormat.clock(engine.lastRefresh ?? portfolio.lastRefresh),
            aiActivationLabel: activationCycleLabel,
            aiActivationDetail: activationCycleDetail,
            aiActivationTint: activationCycleTint,
            softCycleCountText: "\(engine.dailySoftCycleCount)",
            heavyCycleCountText: "\(engine.dailyHeavyCycleCount)",
            cashBalanceText: dashboardCashBalanceText,
            holdingsValueText: dashboardHoldingsValueText,
            accountValueText: dashboardAccountValueText,
            accountValueTint: wealthRelativeTint(current: displayedAccountValue, baseline: max(portfolio.capitalBaseline, 1)),
            buyReservedText: dashboardBuyReservedText,
            sellReturningText: dashboardSellReturningText,
            totalPnLText: dashboardTotalPnLText,
            totalPnLTint: dashboardTotalPnLTint
        )
    }

    @ViewBuilder
    var phoneSafeMainContent: some View {
        switch mainTab {
        case .dashboard:
            phoneSafeDashboardSection
                .frame(maxWidth: .infinity, alignment: .topLeading)
        case .activity:
            VStack(spacing: 10) {
                sectionShell(title: "ACTIVITY", subtitle: "Pending buys, sells and data rechecks")
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
                    moments: [],
                    onSelectHolding: { selectedHolding = $0 },
                    onSelectOpportunity: { selectedOpportunity = $0 }
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        case .markets:
            VStack(spacing: 10) {
                sectionShell(title: "MARKETS", subtitle: "Global scan universe and capital routing")
                MarketsView()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        case .campaign:
            VStack(spacing: 10) {
                sectionShell(title: "CAMPAIGN", subtitle: "Profit-only daily, compound and mission ladder")
                CampaignView()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        case .system:
            SystemView()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    var bottomDock: some View {
        HStack(spacing: 6) {
            ForEach(MainTab.allCases) { tab in
                let selected = tab == mainTab
                Button {
                    mainTab = tab
                } label: {
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .black))
                            Text(tab.rawValue)
                                .font(.system(size: 9, weight: .black, design: .rounded))
                        }

                        if tab == .activity, activityBadgeCount > 0 {
                            Text("\(activityBadgeCount)")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(WealthTheme.orange)
                                .clipShape(Capsule())
                                .offset(x: 8, y: -6)
                        }
                    }
                    .foregroundColor(selected ? .black : .white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selected ? AnyShapeStyle(tab.accent) : AnyShapeStyle(Color.clear))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color(red: 0.10, green: 0.08, blue: 0.18).opacity(0.92),
                            Color(red: 0.12, green: 0.05, blue: 0.16).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
}
