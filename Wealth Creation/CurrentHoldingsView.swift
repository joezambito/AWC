import SwiftUI

struct CurrentHoldingsView: View {
    let holdings: [Holding]
    let onSelect: (Holding) -> Void

    @State private var expandedHoldings: Set<String> = []

    private var sortedHoldings: [Holding] {
        holdings.sorted {
            let leftFilledAt = $0.filledAt ?? .distantPast
            let rightFilledAt = $1.filledAt ?? .distantPast
            if leftFilledAt != rightFilledAt { return leftFilledAt > rightFilledAt }
            return $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending
        }
    }

    private var hasDesktopLayout: Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }

    var body: some View {
        LazyVStack(spacing: 10) {
            if hasDesktopLayout {
                HStack {
                    HStack(spacing: 12) {
                        iconBadge("briefcase.fill", tint: WealthTheme.gold)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CURRENT HOLDINGS")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Open positions, AI signal status and live holding detail")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(WealthTheme.grey)
                        }
                    }

                    Spacer()

                    solidPill("\(holdings.count) LIVE", color: WealthTheme.gold, darkText: true)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }

            ForEach(sortedHoldings) { holding in
                Button {
                    toggleExpanded(holding.id)
                } label: {
                    CurrentHoldingCard(
                        holding: holding,
                        isExpanded: expandedHoldings.contains(holding.id),
                        usesDenseCollapsedState: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .padding(.bottom, hasDesktopLayout ? 10 : 0)
        .background(
            hasDesktopLayout
                ? AnyView(glowPanelShell(cornerRadius: 22, tint: WealthTheme.gold, secondaryTint: WealthTheme.orange))
                : AnyView(Color.clear)
        )
    }

    private func toggleExpanded(_ holdingID: String) {
        if expandedHoldings.contains(holdingID) {
            expandedHoldings.remove(holdingID)
        } else {
            expandedHoldings.insert(holdingID)
        }
    }
}
