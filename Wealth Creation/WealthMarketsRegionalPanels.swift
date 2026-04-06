import SwiftUI

private enum PreparedWorldMarketsPanelConstants {
    static let regionOrder = ["US", "CA", "EU", "APAC", "ME", "LATAM", "AFRICA", "AU", "FX", "CRYPTO", "GLOBAL", "UNKNOWN"]
}

private func globalMarketTotalsPill(title: String, count: Int, tint: Color) -> some View {
    VStack(spacing: 2) {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(tint.opacity(0.9))
        Text("\(count)")
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundColor(tint)
    }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.30), lineWidth: 1)
        )
}

private struct PreparedWorldMarketsPanel<RowContent: View, RegionCardContent: View>: View {
    @ObservedObject private var engine = WealthEngineStore.shared

    let topEntries: [MarketUniverseEntry]
    let hasDesktopLayout: Bool
    @Binding var expandedMarketRegion: String?
    let rowContent: (MarketUniverseEntry) -> RowContent
    let regionCardContent: (MarketRegionBoardSummary) -> RegionCardContent

    private var groupedRows: [(region: String, entries: [MarketUniverseEntry])] {
        Dictionary(grouping: Array(topEntries.prefix(100)), by: \.region)
            .map { (region: $0.key, entries: $0.value) }
            .sorted { lhs, rhs in
                let leftIndex = PreparedWorldMarketsPanelConstants.regionOrder.firstIndex(of: lhs.region) ?? .max
                let rightIndex = PreparedWorldMarketsPanelConstants.regionOrder.firstIndex(of: rhs.region) ?? .max
                return leftIndex == rightIndex ? lhs.region < rhs.region : leftIndex < rightIndex
            }
    }

    private var globalTotals: [(id: String, title: String, count: Int, tint: Color)] {
        return [
            ("total", "TOTAL", topEntries.count, WealthTheme.cyan),
            ("green", "GREEN", topEntries.filter { $0.tint == WealthTheme.green }.count, WealthTheme.green),
            ("blue", "BLUE", topEntries.filter { $0.tint == WealthTheme.blue }.count, WealthTheme.blue),
            ("purple", "PURPLE", topEntries.filter { $0.tint == WealthTheme.purple }.count, WealthTheme.purple),
            ("red", "RED", topEntries.filter { $0.tint == WealthTheme.red }.count, WealthTheme.red),
            ("grey", "GREY", topEntries.filter { $0.tint == WealthTheme.grey }.count, WealthTheme.grey)
        ]
    }

    private var boardSummaries: [MarketRegionBoardSummary] {
        groupedRows.map { group in
            let entries = group.entries
            let leadEntry = entries.first
            return MarketRegionBoardSummary(
                region: group.region,
                market: leadEntry?.market ?? group.region,
                state: BrokerSessionClock.state(
                    for: leadEntry?.market ?? group.region,
                    brokerName: WealthBrokerStore.shared.selectedBroker.name
                ),
                rawCount: entries.count,
                greenCount: entries.filter { $0.tint == WealthTheme.green }.count,
                blueCount: entries.filter { $0.tint == WealthTheme.blue }.count,
                purpleCount: entries.filter { $0.tint == WealthTheme.purple }.count,
                redCount: entries.filter { $0.tint == WealthTheme.red }.count,
                greyCount: entries.filter { $0.tint == WealthTheme.grey }.count,
                accentTint: leadEntry?.tint ?? WealthTheme.grey
            )
        }
    }

    var body: some View {
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 10) {
                    iconBadge("globe.americas.fill", tint: WealthTheme.cyan)
                        .frame(width: 54, height: 54)
                        .scaleEffect(0.78)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("WORLD MARKETS")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(engine.isUsingCachedMarketData ? "Restored market snapshot while refresh runs" : "Collapsed market board by region")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                }

                Spacer()
                solidPill(engine.isUsingCachedMarketData ? "CACHED" : "LIVE", color: engine.isUsingCachedMarketData ? WealthTheme.orange : WealthTheme.green, darkText: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(globalTotals, id: \.id) { item in
                        globalMarketTotalsPill(title: item.title, count: item.count, tint: item.tint)
                    }
                }
            }

            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(groupedRows, id: \.region) { group in
                    if let summary = boardSummaries.first(where: { $0.region == group.region }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                expandedMarketRegion = expandedMarketRegion == group.region ? nil : group.region
                            } label: {
                                regionCardContent(summary)
                            }
                            .buttonStyle(.plain)

                            if expandedMarketRegion == group.region {
                                LazyVStack(spacing: 8) {
                                    ForEach(group.entries) { entry in
                                        rowContent(entry)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(cardShell(cornerRadius: hasDesktopLayout ? 24 : 18))
    }
}

extension MarketsView {
    // MARK: Layout
    private var worldMarketBoardColumns: [GridItem] {
        hasDesktopLayout
            ? [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            : [GridItem(.flexible(), spacing: 8)]
    }

    var worldMarketsPanel: some View {
        Group {
            if hasDesktopLayout {
                PreparedWorldMarketsPanel(
                    topEntries: top100MarketEntries.map(\.entry),
                    hasDesktopLayout: hasDesktopLayout,
                    expandedMarketRegion: $expandedMarketRegion,
                    rowContent: { entry in
                        marketCompactShareRow(entry)
                    },
                    regionCardContent: { summary in
                        marketRegionCard(summary: summary)
                    }
                )
            } else {
                phoneTop100MarketsPanel
            }
        }
    }

    var regionalCalendarPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("REGIONAL CALENDAR")
                        .font(.system(size: hasDesktopLayout ? 14 : 13, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                    Text("Region trading windows from the live market clock")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()
                solidPill("IBKR", color: WealthTheme.blue, darkText: false)
            }

            LazyVStack(spacing: 8) {
                ForEach(regionCalendarEntries) { entry in
                    regionalCalendarRow(entry)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glowPanelShell(cornerRadius: hasDesktopLayout ? 22 : 18, tint: WealthTheme.blue, secondaryTint: WealthTheme.cyan))
    }

    func regionalCalendarRow(_ entry: MarketRegionCalendarEntry) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.region)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(entry.market)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Text("\(entry.marketCount) MARKETS TRACKED")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                solidPill(entry.state.rawValue, color: entry.state.color, darkText: entry.state != .waitingForOpen)
                Text(entry.nextTradeText.uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.82))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(cardShell(cornerRadius: 16))
    }

    private func deferredRegionPhaseLabel(for region: String) -> String? {
        guard !hasDesktopLayout else { return nil }

        switch region {
        case "GLOBAL":
            return phoneMarketCycleStage >= 1 ? nil : "LOADS IN CYCLE 1/2"
        case "UNKNOWN":
            return phoneMarketCycleStage >= 2 ? nil : "LOADS IN CYCLE 2/2"
        default:
            return nil
        }
    }
}
