import SwiftUI

extension MarketsView {
    func marketSnapshotRow(name: String, symbol: String, value: String, change: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(symbol)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(change)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(WealthTheme.green)
            }
        }
        .padding(12)
        .background(cardShell(cornerRadius: 16))
    }

    func marketSnapshotSection(region: String, entries: [MarketUniverseEntry]) -> some View {
        let regionKey = "snapshot-\(region)"
        let isExpanded = expandedRegions.contains(regionKey)
        let lead = entries.first

        return VStack(spacing: 8) {
            Button {
                toggleRegion(regionKey)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(region)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(entries.count) market cards")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    Spacer()
                    if let lead {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(lead.symbol)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(lead.tint)
                            Text(lead.priceText)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(12)
                .background(cardShell(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(entries) { entry in
                    marketSnapshotRow(
                        name: entry.marketDisplayLabel,
                        symbol: entry.symbol,
                        value: entry.priceText,
                        change: entry.changeText
                    )
                }
            }
        }
    }
}
