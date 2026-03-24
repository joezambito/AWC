import SwiftUI

struct WealthPhoneSafeHeaderView: View {
    let lastRefreshText: String
    let aiActivationLabel: String
    let aiActivationDetail: String
    let aiActivationTint: Color
    let softCycleCountText: String
    let heavyCycleCountText: String
    let cashBalanceText: String
    let holdingsValueText: String
    let accountValueText: String
    let accountValueTint: Color
    let buyReservedText: String
    let sellReturningText: String
    let totalPnLText: String
    let totalPnLTint: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                brandLogoTile(size: 68, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ZULUGAMES")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)
                    Text("Autonomous Wealth Creation")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("AI ONLINE")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.green)
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
                        .minimumScaleFactor(0.78)
                        .foregroundColor(aiActivationTint)
                    if !aiActivationDetail.isEmpty {
                        Text(aiActivationDetail)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .foregroundColor(aiActivationTint)
                    }

                    HStack(spacing: 5) {
                        cycleCountCard(title: "Soft", value: softCycleCountText, tint: WealthTheme.cyan)
                        cycleCountCard(title: "Heavy", value: heavyCycleCountText, tint: WealthTheme.orange)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(WealthTheme.green.opacity(0.18), lineWidth: 0.8)
                        )
                )
            }

            largeCapitalCard(title: "Capital", value: cashBalanceText, accent: .white)

            HStack(spacing: 6) {
                compactSummaryCard(title: "Holdings", value: holdingsValueText, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Account Value", value: accountValueText, tint: accountValueTint)
                compactSummaryCard(title: "P / L", value: totalPnLText, tint: totalPnLTint)
            }

            HStack(spacing: 6) {
                compactSummaryCard(title: "Buy Reserve", value: buyReservedText, tint: WealthTheme.blue)
                compactSummaryCard(title: "Sell Returning", value: sellReturningText, tint: WealthTheme.purple)
            }
        }
        .padding(7)
        .background(cardShell(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(WealthTheme.cyan.opacity(0.16), lineWidth: 0.9)
        )
    }

    private func largeCapitalCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
            Text(value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(cardShell(cornerRadius: 14))
    }

    private func cycleCountCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(cardShell(cornerRadius: 11))
    }
}
