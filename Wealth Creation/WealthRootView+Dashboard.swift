import SwiftUI

extension WealthRootView {
    var dashboardSection: some View {
        if !hasDesktopLayout {
            return AnyView(phoneSafeDashboardSection)
        }

        return AnyView(
            VStack(spacing: 8) {
                VStack(spacing: 8) {
                    segmentBar(
                        options: DashboardMode.allCases.map(\.rawValue),
                        selected: dashboardMode.rawValue,
                        activeColor: dashboardMode == .holdings ? WealthTheme.green : WealthTheme.cyan
                    ) { value in
                        dashboardMode = DashboardMode(rawValue: value) ?? .holdings
                    }

                    holdingsStatusBox
                }
                .padding(9)
                .background(glowPanelShell(cornerRadius: 22, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))

                dashboardIntelDeck

                switch dashboardMode {
                case .holdings:
                    CurrentHoldingsView(holdings: confirmedHoldings) { selectedHolding = $0 }
                case .livePicks:
                    BrainPicksView(opportunities: livePickOpportunities) { selectedOpportunity = $0 }
                }
            }
        )
    }

    var phoneSafeDashboardSection: some View {
        VStack(spacing: 10) {
            WealthPhoneDashboardSectionView(
                options: DashboardMode.allCases.map(\.rawValue),
                selected: dashboardMode.rawValue,
                activeColor: dashboardMode == .holdings ? WealthTheme.green : WealthTheme.cyan,
                holdingsCount: confirmedHoldings.count,
                showStatusBox: dashboardMode == .holdings && confirmedHoldings.isEmpty
            ) { value in
                dashboardMode = DashboardMode(rawValue: value) ?? .holdings
            }

            switch dashboardMode {
            case .holdings:
                if confirmedHoldings.isEmpty {
                    EmptyView()
                } else {
                    CurrentHoldingsView(holdings: confirmedHoldings) { selectedHolding = $0 }
                }
            case .livePicks:
                BrainPicksView(opportunities: livePickOpportunities) { selectedOpportunity = $0 }
            }
        }
    }

    var holdingsStatusBox: some View {
        WealthHoldingsStatusBox(count: confirmedHoldings.count)
    }

    var headerCard: some View {
        WealthHeaderCardView(
            hasDesktopLayout: hasDesktopLayout,
            lastRefreshText: WealthFormat.clock(engine.lastRefresh ?? portfolio.lastRefresh),
            aiActivationLabel: activationCycleLabel,
            aiActivationDetail: activationCycleDetail,
            aiActivationTint: activationCycleTint,
            cashBalanceText: dashboardCashBalanceText,
            holdingsValueText: dashboardHoldingsValueText,
            accountValueText: dashboardAccountValueText,
            floorReserveText: WealthFormat.money(portfolio.floorReserve),
            buyReservedText: dashboardBuyReservedText,
            sellReturningText: dashboardSellReturningText,
            totalPnLText: dashboardTotalPnLText,
            totalPnLTint: dashboardTotalPnLTint
        )
    }

    var dashboardIntelDeck: some View {
        VStack(spacing: 12) {
            if hasDesktopLayout {
                dashboardTrendPanel
            }
        }
    }

    var dashboardTrendPanel: some View {
        WealthDashboardTrendPanel(
            goalVector: goalVector,
            brainSnapshot: engine.brainSnapshot,
            aiFlowPoints: aiFlowPoints,
            lastRefreshText: WealthFormat.clock(engine.lastRefresh ?? portfolio.lastRefresh)
        )
    }
}
