import SwiftUI

struct OpportunityCardHeaderView: View {
    let opportunity: Opportunity
    let isExpanded: Bool
    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(opportunity.symbol)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(marketScheduleText.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(marketStatusText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(marketStatusTint)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(opportunity.marketDisplayLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    compactStatusPill(statusText, color: statusTint)

                    if protection.shieldPercent > 0 {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(WealthTheme.orange)
                    }
                    if protection.surgeEnabled {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(WealthTheme.gold)
                    }
                }

                HStack(spacing: 6) {
                    Text("RANK #\(opportunity.rank)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.cyan)

                    Text(isExpanded ? "EXPANDED" : "COLLAPSED")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
            }
        }
    }

    private var marketStatusText: String {
        switch opportunity.sessionState {
        case .tradableNow:
            return "MARKET OPEN"
        case .afterHours:
            return "MARKET CLOSED"
        case .waitingForOpen, .recheckAtOpen:
            return "MARKET CLOSED"
        }
    }

    private var marketStatusTint: Color {
        switch opportunity.sessionState {
        case .tradableNow:
            return WealthTheme.green
        case .afterHours:
            return WealthTheme.red
        case .waitingForOpen, .recheckAtOpen:
            return WealthTheme.blue
        }
    }

    private var marketScheduleText: String {
        switch opportunity.sessionState {
        case .tradableNow:
            return "Open now"
        case .afterHours, .waitingForOpen, .recheckAtOpen:
            return "Opens at \(opportunity.nextTradingText)"
        }
    }

    private var statusText: String {
        switch opportunity.orderState {
        case .submitted:
            return "ORDER SUBMITTED"
        case .pending:
            return "ORDER PENDING"
        case .partial:
            return "ORDER SENT"
        case .filled:
            return opportunity.decisionBias == .avoid ? "SELL FILLED" : "BUY FILLED"
        case .ready:
            if opportunity.permission == .go {
                return opportunity.sessionState.canTradeNow ? "ORDER SENT" : "ORDER PENDING"
            }
            return opportunity.permission == .wait ? "WAIT" : "BLOCKED"
        }
    }

    private var statusTint: Color {
        switch opportunity.orderState {
        case .submitted, .pending, .partial:
            return orderStateTint(opportunity.orderState)
        case .filled:
            return WealthTheme.white
        case .ready:
            if opportunity.permission == .go {
                return opportunity.sessionState.canTradeNow ? WealthTheme.green : WealthTheme.gold
            }
            return opportunity.permission.color
        }
    }

    private func compactStatusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }
}
