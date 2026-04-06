import SwiftUI

struct PendingOpportunitySection: View {
    private enum StorageKey {
        static let expandedIDs = "awc_activity_pending_opps_expanded_ids"
        static let visibleCount = "awc_activity_pending_opps_visible_count"
    }

    let opportunities: [Opportunity]
    @State private var expandedSymbols: Set<String> = []
    @State private var visibleCount = 20
    @AppStorage(StorageKey.expandedIDs) private var persistedExpandedIDs = ""
    @AppStorage(StorageKey.visibleCount) private var persistedVisibleCount = 20

    private var sortedOpportunities: [Opportunity] {
        opportunities.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending
        }
    }

    private var visibleOpportunities: [Opportunity] {
        Array(sortedOpportunities.prefix(visibleCount))
    }

    var body: some View {
        // MARK: Activity Group Layout
        // Safe manual tweak area:
        // - section VStack spacing
        // - header-to-card gap
        // - bottom padding
        VStack(spacing: 12) {
            sectionHeader(
                title: "PENDING BUYS",
                subtitle: "Final activity checks before submission",
                badge: "Tracking \(opportunities.count)",
                badgeColor: WealthTheme.purple,
                darkBadgeText: false
            )

            ForEach(visibleOpportunities) { opportunity in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        toggleExpanded(opportunity.id)
                    }
                } label: {
                    OpportunityCard(
                        opportunity: opportunity,
                        accentTint: WealthTheme.purple,
                        statusBadgeText: pendingBuyStatusText(for: opportunity),
                        secondaryStatusText: opportunity.marketDisplayLabel,
                        isExpanded: expandedSymbols.contains(opportunity.id),
                        usesDenseCollapsedState: true
                    )
                }
                .buttonStyle(.plain)
            }

            if sortedOpportunities.count > visibleCount {
                Button {
                    visibleCount += 20
                } label: {
                    Text("SHOW MORE")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(WealthTheme.cyan)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 12)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.purple, secondaryTint: WealthTheme.cyan))
        .onAppear {
            if expandedSymbols.isEmpty, !persistedExpandedIDs.isEmpty {
                expandedSymbols = Set(persistedExpandedIDs.split(separator: ",").map(String.init))
            }
            if visibleCount == 20, persistedVisibleCount > 20 {
                visibleCount = persistedVisibleCount
            }
            syncVisibleState()
        }
        .onChange(of: opportunities.map(\.id)) { _, _ in
            syncVisibleState()
        }
        .onChange(of: expandedSymbols) { _, newValue in
            persistedExpandedIDs = newValue.sorted().joined(separator: ",")
        }
        .onChange(of: visibleCount) { _, newValue in
            persistedVisibleCount = max(20, newValue)
        }
    }

    private func toggleExpanded(_ id: String) {
        if expandedSymbols.contains(id) {
            expandedSymbols.remove(id)
        } else {
            expandedSymbols.insert(id)
        }
    }

    private func syncVisibleState() {
        let validIDs = Set(sortedOpportunities.map(\.id))
        let filteredExpanded = expandedSymbols.filter { validIDs.contains($0) }
        if filteredExpanded != expandedSymbols {
            expandedSymbols = filteredExpanded
        }

        if sortedOpportunities.isEmpty {
            visibleCount = 20
            return
        }

        visibleCount = min(max(20, visibleCount), sortedOpportunities.count)
    }

    private func pendingBuyStatusText(for opportunity: Opportunity) -> String {
        switch opportunity.orderState {
        case .submitted:
            return "ORDER SUBMITTED"
        case .pending:
            return "ORDER PENDING"
        case .partial:
            return "ORDER SENT"
        case .filled:
            return opportunity.decisionBias == .avoid ? "SELL FILLED" : "BUY FILLED"
        case .ready:
            return opportunity.sessionState.canTradeNow ? "ORDER SENT" : "ORDER PENDING"
        }
    }
}

struct PendingHoldingSection: View {
    let holdings: [Holding]
    @State private var expandedSymbols: Set<String> = []

    private var sortedHoldings: [Holding] {
        holdings.sorted {
            if $0.aiScore != $1.aiScore { return $0.aiScore < $1.aiScore }
            return $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            sectionHeader(
                title: "PENDING SELLS",
                subtitle: "Waiting for broker and data confirmation",
                badge: "\(holdings.count) ACTIVE",
                badgeColor: WealthTheme.purple,
                darkBadgeText: false
            )

            ForEach(sortedHoldings) { holding in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        toggleExpanded(holding.symbol)
                    }
                } label: {
                    PendingHoldingCard(
                        holding: holding,
                        isExpanded: expandedSymbols.contains(holding.symbol),
                        usesDenseCollapsedState: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 9)
        .background(glowPanelShell(cornerRadius: 22, tint: WealthTheme.purple, secondaryTint: WealthTheme.cyan))
    }

    private func toggleExpanded(_ symbol: String) {
        if expandedSymbols.contains(symbol) {
            expandedSymbols.remove(symbol)
        } else {
            expandedSymbols.insert(symbol)
        }
    }
}

struct RecentCompletedSection: View {
    let opportunities: [Opportunity]
    @State private var expandedSymbols: Set<String> = []

    private var sortedOpportunities: [Opportunity] {
        opportunities.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            sectionHeader(
                title: "RECENT COMPLETED",
                subtitle: "Latest fills and completed order actions",
                badge: "\(opportunities.count) DONE",
                badgeColor: Color.white.opacity(0.82),
                darkBadgeText: true
            )

            ForEach(sortedOpportunities.prefix(3)) { opportunity in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        toggleExpanded(opportunity.symbol)
                    }
                } label: {
                    CompletedOpportunityCard(
                        opportunity: opportunity,
                        isExpanded: expandedSymbols.contains(opportunity.symbol),
                        usesDenseCollapsedState: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 9)
        .background(glowPanelShell(cornerRadius: 22, tint: Color.white.opacity(0.92), secondaryTint: WealthTheme.cyan))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func toggleExpanded(_ symbol: String) {
        if expandedSymbols.contains(symbol) {
            expandedSymbols.remove(symbol)
        } else {
            expandedSymbols.insert(symbol)
        }
    }
}
