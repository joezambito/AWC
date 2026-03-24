import SwiftUI

struct PendingOpportunitySection: View {
    let opportunities: [Opportunity]
    @State private var expandedSymbols: Set<String> = []

    private var sortedOpportunities: [Opportunity] {
        opportunities.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            sectionHeader(
                title: "AI LIVE",
                subtitle: "Live trading feed",
                badge: "Tracking \(opportunities.count)",
                badgeColor: WealthTheme.purple,
                darkBadgeText: false
            )

            ForEach(sortedOpportunities) { opportunity in
                OpportunityCard(
                    opportunity: opportunity,
                    isExpanded: expandedSymbols.contains(opportunity.symbol),
                    onToggle: { toggleExpanded(opportunity.symbol) },
                    allowsInlineToggle: true
                )
            }
        }
        .padding(.bottom, 12)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.purple, secondaryTint: WealthTheme.cyan))
    }

    private func toggleExpanded(_ symbol: String) {
        if expandedSymbols.contains(symbol) {
            expandedSymbols.remove(symbol)
        } else {
            expandedSymbols.insert(symbol)
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
