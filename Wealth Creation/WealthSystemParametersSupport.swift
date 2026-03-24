import SwiftUI

extension WealthSystemParametersSection {
    var desktopParametersLeadCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(colors: [WealthTheme.cyan.opacity(0.18), WealthTheme.blue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(WealthTheme.cyan.opacity(0.30), lineWidth: 0.9)
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(WealthTheme.cyan)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("SYSTEM PARAMETERS")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Brain protection, exits, reserve, refresh and demo controls")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()
                solidPill("ONLINE", color: WealthTheme.green, darkText: true)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Shield", value: "\(Int(protection.shieldPercent))%", tint: WealthTheme.red)
                compactSummaryCard(title: "Profit", value: "\(Int(protection.profitTargetValue))%", tint: WealthTheme.green)
                compactSummaryCard(title: "Floor", value: WealthFormat.money(protection.floorReserve), tint: WealthTheme.purple)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    var protectionPanel: some View {
        Group {
            switch protectionTab {
            case .shield:
                protectionInputCard(
                    title: "CAPITAL SHIELD",
                    detail: "Protection floor. If a share drops by this amount from entry, the brain sells to protect capital.",
                    fieldTitle: "MAX LOSS",
                    field: percentField(value: $protection.shieldPercent, tint: WealthTheme.red)
                )
            case .profit:
                protectionInputCard(
                    title: "PROFIT LOCK",
                    detail: "When a winner reaches this profit level, the brain starts protecting gains instead of letting the whole move stay exposed.",
                    fieldTitle: "LOCK AT",
                    field: percentField(value: $protection.profitTargetValue, tint: WealthTheme.green)
                )
            case .floor:
                protectionInputCard(
                    title: "FLOOR RESERVE",
                    detail: "The brain keeps this amount reserved as a protected floor before it treats the rest as free growth capital.",
                    fieldTitle: "RESERVE FLOOR",
                    field: moneyField(value: $protection.floorReserve, tint: WealthTheme.purple)
                )
            }
        }
    }
}
