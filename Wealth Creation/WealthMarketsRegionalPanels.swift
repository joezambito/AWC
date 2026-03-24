import SwiftUI

extension MarketsView {
    var worldMarketsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasDesktopLayout {
                HStack {
                    HStack(spacing: 10) {
                        iconBadge("globe.americas.fill", tint: WealthTheme.cyan)
                            .frame(width: 54, height: 54)
                            .scaleEffect(0.78)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("WORLD MARKETS")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Full enabled market shelf by region")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(WealthTheme.grey)
                        }
                    }

                    Spacer()
                    solidPill("LIVE", color: WealthTheme.green, darkText: true)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(universeByRegion, id: \.region) { group in
                    marketRegionCard(
                        region: group.region,
                        entries: marketRegionIsActive(group.region) ? group.items : [],
                        rawCount: marketRegionRawCounts[group.region] ?? group.items.count,
                        phaseLabel: deferredRegionPhaseLabel(for: group.region)
                    )
                }
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: hasDesktopLayout ? 24 : 18, tint: WealthTheme.green, secondaryTint: WealthTheme.cyan))
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
