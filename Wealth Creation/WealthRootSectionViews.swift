import SwiftUI

struct WealthHeaderCardView: View {
    let hasDesktopLayout: Bool
    let lastRefreshText: String
    let aiActivationLabel: String
    let aiActivationDetail: String
    let aiActivationTint: Color
    let cashBalanceText: String
    let holdingsValueText: String
    let accountValueText: String
    let floorReserveText: String
    let buyReservedText: String
    let sellReturningText: String
    let totalPnLText: String
    let totalPnLTint: Color

    var body: some View {
        let pnlTag = totalPnLTint == WealthTheme.green ? "GAIN" : (totalPnLTint == WealthTheme.red ? "LOSS" : "EVEN")

        VStack(spacing: hasDesktopLayout ? 8 : 5) {
            HStack(spacing: 8) {
                brandLogoTile(size: 58, cornerRadius: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ZULUGAMES")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                    Text("Autonomous Wealth Creation")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last Refresh")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                    Text(lastRefreshText)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.green)
                    Text(aiActivationLabel)
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .foregroundColor(aiActivationTint)
                    if !aiActivationDetail.isEmpty {
                        Text(aiActivationDetail)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .foregroundColor(aiActivationTint)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(cardShell(cornerRadius: 14))
            }

            if hasDesktopLayout {
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        bigSummaryCard(
                            title: "Capital",
                            value: cashBalanceText,
                            caption: "AUD",
                            accent: .white
                        )
                        balanceReferenceCard(
                            title: "Holdings",
                            value: holdingsValueText,
                            accent: WealthTheme.green
                        )
                        balanceReferenceCard(
                            title: "Account Value",
                            value: accountValueText,
                            accent: WealthTheme.cyan
                        )
                    }

                    HStack(alignment: .top, spacing: 8) {
                        miniReferenceCard(
                            title: "Floor Reserve",
                            value: floorReserveText,
                            accent: WealthTheme.purple,
                            tag: "SAFE"
                        )
                        miniReferenceCard(
                            title: "P / L",
                            value: totalPnLText,
                            accent: totalPnLTint,
                            tag: pnlTag
                        )
                    }

                    HStack(alignment: .top, spacing: 8) {
                        miniReferenceCard(
                            title: "Buy Reserve",
                            value: buyReservedText,
                            accent: WealthTheme.cyan,
                            tag: "HELD"
                        )
                        miniReferenceCard(
                            title: "Sell Returning",
                            value: sellReturningText,
                            accent: WealthTheme.purple,
                            tag: "INBOUND"
                        )
                    }

                    Text("The brain reads your live broker balance, protects the floor, and only deploys clean available capital into the next trade.")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Capital")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.58))
                        Text(cashBalanceText)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text("AUD")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(hasDesktopLayout ? 10 : 7)
        .background(glowPanelShell(cornerRadius: 22, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(WealthTheme.cyan.opacity(0.18), lineWidth: 1))
    }
}
