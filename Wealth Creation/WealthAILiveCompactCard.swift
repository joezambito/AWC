import SwiftUI

// MARK: - WealthAILiveCompactCard
//
// A compact SwiftUI card that surfaces the primary AI Live selection.
// Primary selection logic lives in the real Xcode project source.
// This file is a placeholder to avoid phantom @StateObject/shared references.

struct WealthAILiveCompactCard: View {

    @EnvironmentObject private var engine: WealthEngineStore

    var body: some View {
        let promotedCard = primarySelection
        if let card = promotedCard {
            cardView(card)
        } else {
            emptyView
        }
    }

    private var primarySelection: Opportunity? {
        let portfolio = WealthPortfolioStore.shared
        let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        return WealthAILiveCoordinator.livePicks(
            from: engine.rankedAssets,
            aiLiveResults: engine.aiLiveResultsByKey,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: portfolio.freeBuyingPower
        )
        .sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.symbol < $1.symbol
        }
        .first
    }

    // MARK: - Sub-views

    private func cardView(_ opportunity: Opportunity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.green)
                Text("AI Live")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Spacer()
                Text("Rank #\(opportunity.rank)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(opportunity.symbol)
                .font(.headline)

            HStack(spacing: 12) {
                Label {
                    Text(String(format: "%.1f", opportunity.aiScore))
                } icon: {
                    Image(systemName: "brain")
                        .foregroundStyle(.blue)
                }
                .font(.subheadline)

                Label {
                    Text(String(format: "%.0f%%", opportunity.probability * 100))
                } icon: {
                    Image(systemName: "percent")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyView: some View {
        HStack {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(.secondary)
            Text("No AI Live pick")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
