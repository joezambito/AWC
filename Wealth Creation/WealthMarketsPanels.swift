import SwiftUI

extension MarketsView {
    var marketDesktopRail: some View {
        VStack(spacing: 10) {
            desktopMarketCard(
                title: "MARKET PULSE",
                subtitle: "Top live regions from the current scan",
                tint: WealthTheme.cyan,
                rows: Array(universeByRegion.prefix(4)).map { group in
                    let lead = group.items.first
                    return (group.region, lead?.statusText ?? "LIVE")
                }
            )

            desktopMarketCard(
                title: "THEME HEAT",
                subtitle: "Top ranked sectors from the current scan",
                tint: WealthTheme.purple,
                rows: Array(engine.rankedAssets.prefix(4)).map { opportunity in
                    (opportunity.sector.uppercased(), opportunity.cardSignalLabel)
                }
            )
        }
    }
}
