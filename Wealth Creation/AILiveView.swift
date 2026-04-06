import SwiftUI

struct BrainPicksView: View {
    let opportunities: [Opportunity]
    let onSelect: (Opportunity) -> Void
    @State private var expandedSymbols: Set<String> = []

    private var sortedOpportunities: [Opportunity] {
        opportunities.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI LIVE")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Live trading feed")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.purple)
                }
                Spacer()
                solidPill("Tracking \(opportunities.count)", color: WealthTheme.purple, darkText: false)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            ForEach(sortedOpportunities) { opportunity in
                OpportunityCard(
                    opportunity: opportunity,
                    isExpanded: expandedSymbols.contains(opportunity.symbol),
                    onToggle: {
                        toggle(opportunity.symbol)
                    }
                )
            }
        }
        .padding(.bottom, 12)
        .background(glowPanelShell(cornerRadius: 28, tint: WealthTheme.purple, secondaryTint: WealthTheme.cyan))
    }

    private func toggle(_ symbol: String) {
        if expandedSymbols.contains(symbol) {
            expandedSymbols.remove(symbol)
        } else {
            expandedSymbols.insert(symbol)
        }
    }
}
