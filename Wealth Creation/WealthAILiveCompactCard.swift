import SwiftUI

// MARK: - WealthAILiveCompactCard
//
// A compact SwiftUI card that surfaces the primary AI Live selection
// (the highest-ranked promoted opportunity) inline in any dashboard or
// panel view.
//
// Usage:
//   WealthAILiveCompactCard()
//     .environmentObject(WealthEngineStore.shared)

struct WealthAILiveCompactCard: View {

    // MARK: - State

    @StateObject private var coordinator = WealthAILiveCoordinator.shared

    // MARK: - Body

    var body: some View {
        if let card = WealthAILiveCoordinator.shared.primarySelection {
            cardView(card)
        } else {
            emptyView
        }
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
