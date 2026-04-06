import SwiftUI

extension MarketsView {
    typealias RankedMarketEntry = (rank: Int, entry: MarketUniverseEntry)

    private struct PhoneTop100Group: Identifiable {
        let id: Int
        let title: String
        let entries: [MarketUniverseEntry]
    }

    var top100MarketEntries: [RankedMarketEntry] {
        let brokerName = WealthBrokerStore.shared.selectedBroker.name
        return Array(allCardsStore.currentMarketCards(preferredRefreshTime: engine.lastRefresh).prefix(100)).map { opportunity in
            (
                rank: max(opportunity.rank, 1),
                entry: marketFeedEntry(for: opportunity, brokerName: brokerName)
            )
        }
    }

    private var phoneTop100Groups: [PhoneTop100Group] {
        let entries = top100MarketEntries.map(\.entry)
        return stride(from: 0, to: entries.count, by: 10).map { start in
            let end = min(start + 10, entries.count)
            let groupNumber = (start / 10) + 1
            return PhoneTop100Group(
                id: groupNumber - 1,
                title: "\(groupNumber * 10 - 9)-\(end)",
                entries: Array(entries[start..<end])
            )
        }
    }

    var phoneTop100MarketsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MARKETS")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Top 100 ranked market cards.")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()

                solidPill("\(top100MarketEntries.count) ACTIVE", color: WealthTheme.green, darkText: true)
            }

            let colorSummary = allCardsStore.colorDiagnosticsSummary
            marketTop100SummaryRow([
                (title: "TOTAL", count: universeStore.records.count, tint: WealthTheme.cyan),
                (title: "GREEN", count: colorSummary.green, tint: WealthTheme.green),
                (title: "BLUE", count: colorSummary.blue, tint: WealthTheme.blue),
                (title: "PURPLE", count: colorSummary.purple, tint: WealthTheme.purple),
                (title: "RED", count: colorSummary.red, tint: WealthTheme.red),
                (title: "GREY", count: colorSummary.grey, tint: WealthTheme.grey)
            ])

            VStack(alignment: .leading, spacing: 12) {
                ForEach(phoneTop100Groups) { group in
                    phoneTop100GroupSection(group)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardShell(cornerRadius: 18))
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func phoneTop100GroupSection(_ group: PhoneTop100Group) -> some View {
        let isExpanded = expandedTop100GroupIndex == group.id

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                if expandedTop100GroupIndex == group.id {
                    expandedTop100GroupIndex = nil
                } else {
                    expandedTop100GroupIndex = group.id
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOP 100")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Cards \(group.title)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }

                    Spacer()

                    solidPill("\(group.entries.count)", color: WealthTheme.green, darkText: true)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(WealthTheme.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardShell(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WealthTheme.green.opacity(0.30), lineWidth: isExpanded ? 1.4 : 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(group.entries) { entry in
                        marketCompactShareRow(entry)
                    }
                }
            }
        }
    }

    private func marketTop100SummaryRow(_ metrics: [(title: String, count: Int, tint: Color)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metrics, id: \.title) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.title)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(metric.tint.opacity(0.82))
                        Text("\(metric.count)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(metric.tint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(cardShell(cornerRadius: 14))
                }
            }
        }
    }
}
