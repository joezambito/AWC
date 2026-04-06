import SwiftUI

struct OpportunityCardExpandedDetailsView: View {
    let opportunity: Opportunity
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MARKET RANK")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(WealthTheme.cyan.opacity(0.75))

                Text("#\(opportunity.rank)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(WealthTheme.cyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(cardCellBackground(tint: WealthTheme.cyan))

            detailRow("BUY PRICE", WealthFormat.money(opportunity.submittedPrice), tint: .white)
            detailRow("CURRENT P/L", wealthPnLText(opportunity.liveNetProfit), tint: wealthPnLTint(opportunity.liveNetProfit))
            detailRow("AI SCORE", "\(opportunity.aiScore)", tint: opportunity.scoreTint)
            detailRow("CONFIDENCE", "\(opportunity.confidence)%", tint: opportunity.confidenceTint)
        }
    }

    private var orderStageText: String {
        switch opportunity.orderState {
        case .submitted:
            return "ORDER SUBMITTED"
        case .pending:
            return "ORDER PENDING"
        case .partial:
            return "ORDER SENT"
        case .filled:
            return "ORDER FULFILLED"
        case .ready:
            return opportunity.sessionState.canTradeNow ? "ORDER SENT" : "ORDER PENDING"
        }
    }

    private var orderStageTint: Color {
        switch opportunity.orderState {
        case .filled:
            return WealthTheme.white
        case .ready:
            return opportunity.sessionState.canTradeNow ? WealthTheme.green : WealthTheme.gold
        default:
            return orderStateTint(opportunity.orderState)
        }
    }

    private var priceTint: Color {
        switch opportunity.orderState {
        case .ready:
            return opportunity.sessionState.canTradeNow
                ? (opportunity.priceChangePercent >= 0 ? WealthTheme.green : WealthTheme.orange)
                : opportunity.sessionState.color
        default:
            return orderStateTint(opportunity.orderState)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func detailRow(_ label: String, _ value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(tint.opacity(0.88))
                .frame(width: 98, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(cardCellBackground(tint: tint))
    }

    private func textBlock(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(cardCellBackground(tint: tint))
    }

    private func noteBlock(_ title: String, _ text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(WealthTheme.green)
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(cardCellBackground(tint: WealthTheme.green))
    }

    private func cardCellBackground(tint: Color) -> some View {
        cardShell(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }
}
