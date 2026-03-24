import SwiftUI

extension MarketsView {
    var capitalRoutingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasDesktopLayout {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CAPITAL ROUTING")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.74))
                        Text("Where the AI sees the strongest world flow right now")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    Spacer()
                    solidPill("LIVE", color: WealthTheme.green, darkText: true)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(routingSnapshots) { snapshot in
                    HStack {
                        Circle()
                            .fill(snapshot.tint)
                            .frame(width: 8, height: 8)
                        Text(snapshot.label)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text(snapshot.detail)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(snapshot.tint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(cardShell(cornerRadius: 15))
                }
            }

            Text(capitalRoutingSummary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(10)
                .background(sectionGlowShell(cornerRadius: 16, tint: WealthTheme.cyan))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glowPanelShell(cornerRadius: hasDesktopLayout ? 22 : 18, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
    }

    var snapshotPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasDesktopLayout {
                HStack {
                    iconBadge("globe.americas.fill", tint: WealthTheme.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MARKET SHARE PRICES")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.54))
                        Text("LAST REFRESH  \(WealthFormat.clock(engine.lastRefresh))")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.cyan)
                    }
                    Spacer()
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(universeByRegion, id: \.region) { group in
                    marketSnapshotSection(region: group.region, entries: Array(group.items.prefix(12)))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glowPanelShell(cornerRadius: hasDesktopLayout ? 22 : 18, tint: WealthTheme.blue, secondaryTint: WealthTheme.cyan))
    }

    func marketTogglePanel(title: String, toggles: [(String, Binding<Bool>, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            FlowLayout(spacing: 8) {
                ForEach(Array(toggles.enumerated()), id: \.offset) { _, item in
                    Button {
                        item.1.wrappedValue.toggle()
                        engine.refresh(mode: .soft)
                    } label: {
                        Text(item.0)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(item.1.wrappedValue ? .black : .white.opacity(0.72))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(item.1.wrappedValue ? item.2 : Color.black.opacity(0.28))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardShell(cornerRadius: hasDesktopLayout ? 20 : 18))
    }

    private var capitalRoutingSummary: String {
        guard let region = universeByRegion.first, let symbol = engine.rankedAssets.first else {
            return "The AI is waiting for the next ranked market refresh before routing new capital."
        }

        return "The AI would lean fresh capital toward \(region.region) first, with \(symbol.symbol) currently leading the ranked market feed."
    }
}

func desktopMarketCard(title: String, subtitle: String, tint: Color, rows: [(String, String)]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
        }

        ForEach(rows, id: \.0) { row in
            HStack {
                Text(row.0)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(row.1)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(tint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(cardShell(cornerRadius: 15))
        }
    }
    .padding(12)
    .background(glowPanelShell(cornerRadius: 22, tint: tint, secondaryTint: WealthTheme.blue))
}
