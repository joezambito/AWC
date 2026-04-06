import SwiftUI

struct WealthSystemHelpSection: View {
    let hasDesktopSystemLayout: Bool

    var body: some View {
        Group {
            if hasDesktopSystemLayout {
                GeometryReader { proxy in
                    let isWide = proxy.size.width >= 920

                    ScrollView(.vertical, showsIndicators: false) {
                        helpContent(isWide: isWide)
                    }
                }
            } else {
                helpContent(isWide: false)
            }
        }
    }

    private func helpContent(isWide: Bool) -> some View {
        VStack(spacing: 10) {
            if hasDesktopSystemLayout {
                wealthSystemHeroPanel(
                    title: "HELP / GUIDE",
                    subtitle: "Occasional reference for AI score, confidence, routing and app labels",
                    icon: "questionmark.circle.fill",
                    badge: nil,
                    badgeColor: WealthTheme.purple
                )
            }

            if isWide {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    helpCards
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    phoneHelpHeader
                    helpCards
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var phoneHelpHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HELP / GUIDE")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("Occasional reference for AI score, confidence and app labels")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardShell(cornerRadius: 18))
    }

    @ViewBuilder
    private var helpCards: some View {
        wealthSystemHelpCard(title: "AI SCORE", rows: wealthScoreBandGuideRows(), tint: WealthTheme.cyan)
        wealthSystemHelpCard(title: "CONFIDENCE", rows: wealthConfidenceBandGuideRows(), tint: WealthTheme.green)
        wealthSystemHelpCard(title: "CARD COLOR", rows: ["Green means the All Green checkpoint passed and live P/L is no longer negative", "Blue means watch / wait, including green-qualified setups that turned negative on live P/L", "Purple means AI score and confidence are mixed", "Red means the card failed the checkpoint and is bad overall", "Grey means no data, stale data, or waiting for fresh market data"], tint: WealthTheme.orange)
        wealthSystemHelpCard(title: "AI STATUS", rows: ["1 / 2 to 2 / 2 = opening scan progress", "DATA UP TO DATE = opening cycle finished", "Last cycle line shows SOFT or HEAVY", "Use FORCE REFRESH if the stage gets stuck", "SOFT = faster refresh", "HEAVY = deeper refresh with more info"], tint: WealthTheme.white)
        wealthSystemHelpCard(title: "CARD NUMBERS", rows: ["Closed cards show the actual AI score number and confidence number", "Example: AI Score 19 and Conf 12", "Open the card for the full money, signal, timing, and detail sections"], tint: WealthTheme.blue)
        wealthSystemHelpCard(title: "WHY PICKED", rows: ["WHY PICKED explains why AI chose the share", "This can include recovery, trend, smart money, options, dark pool, insider, 13F, or event reasons", "Open the card to read the full Decision Line and deeper research notes"], tint: WealthTheme.cyan)
        wealthSystemHelpCard(title: "CARD MONEY GUIDE", rows: ["Buy Price = the entry price per share", "Buy Total = full position cost including fee in", "Live Price = latest price now", "Net Exit = estimated sell value after fee out", "Fee In = estimated broker cost on buy", "Fee Out = estimated broker cost on sell", "P/L = green profit or red loss on the holding"], tint: WealthTheme.cyan)
        wealthSystemHelpCard(title: "ACTIVITY STATUS", rows: ["Waiting for Trade = order is ready when the next tradable session opens", "Yellow = submitted or pending order state while the broker is still working", "Buy Submitted / Buy Pending = buy is in progress", "Sale Submitted / Sale Pending = sell is in progress", "White = filled or completed order state after the trade is done"], tint: WealthTheme.purple)
        wealthSystemHelpCard(title: "ACTIVITY MONEY", rows: ["Buy Reserved = money held aside for pending buys", "Sell Returning = money due back after pending sells", "Money only moves back to Trading Capital once broker confirmation finishes", "Cards do not enter buy Activity unless they turn green"], tint: WealthTheme.purple)
        wealthSystemHelpCard(title: "ACTIVITY ROLE", rows: ["Activity is the final protection layer after AI Live", "It banks sale proceeds until the broker confirms the exit", "It keeps reserved buy money parked until the fill completes", "If new live data turns bad, Activity can cancel the pending order before completion"], tint: WealthTheme.purple)
        wealthSystemHelpCard(title: "NEXT TRADE", rows: ["Next Trade follows the next IBKR tradable window for that market", "Where IBKR supports extended-hours, the next trade time uses that window", "Times now show date and AM/PM"], tint: WealthTheme.gold)
        wealthSystemHelpCard(title: "MARKETS BUCKETS", rows: ["Markets appear in this order: US, AU, CA, EU, APAC, ME, LATAM, AFRICA, FX, CRYPTO, GLOBAL, UNKNOWN", "GLOBAL is the catch-bucket for instruments mapped as global, derivatives, bonds, or commodity-style markets", "UNKNOWN is the leftover bucket for records the app could not confidently map to a named region", "On phone, large GLOBAL and UNKNOWN buckets can open into smaller alphabet folders"], tint: WealthTheme.green)
        wealthSystemHelpCard(title: "DATA / TRAINING STACK", rows: ["Options Flow, Dark Pool, Insider and 13F all feed the AI score", "Earnings and Macro layers can reduce trust before risky events", "Outcome learning lifts symbols and sectors that keep working", "Backtest and Retraining improve future ranking quality"], tint: WealthTheme.green)
        wealthSystemHelpCard(title: "AI TUNING", rows: ["BUY GATE = how strict entry must be before AI buys", "Higher buy gate means fewer but stronger setups", "TARGET FIT = how much a trade must help Daily / Compound / Mission", "Higher target fit means AI follows your money goals more tightly", "ROTATE EDGE = how much better a new setup must be before replacing a holding", "FEE EDGE X = extra profit margin required above costs and fees", "PROFIT LOCK = when AI starts protecting gains instead of just letting them run"], tint: WealthTheme.purple)
        wealthSystemHelpCard(title: "AI EFFECT", rows: ["Looser settings give AI more freedom and usually more trades", "Stricter settings make AI wait for stronger, cleaner opportunities", "These settings do not change the goal of making money", "They change how aggressive, selective, and protective AI is while doing it"], tint: WealthTheme.blue)
        wealthSystemHelpCard(title: "BROKERS", rows: ["IBKR stays as the default active broker on phone", "Other brokers should only be searched or reviewed when the brain recommends them", "KEEP IBKR means ignore the suggestion and stay on the current route", "MAKE ACTIVE switches the route only when you decide to use that broker"], tint: WealthTheme.cyan)
        wealthSystemHelpCard(title: "NOTIFICATIONS", rows: ["iPhone alerts can mirror to Apple Watch when watch notifications are enabled", "Queued, pending, filled and capital alerts are all part of the same event layer", "Queensland time stays fixed to AEST with no daylight saving drift"], tint: WealthTheme.green)
    }
}

private func wealthSystemHelpCard(title: String, rows: [String], tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundColor(.white)
        ForEach(rows, id: \.self) { row in
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .padding(.top, 4)
                Text(row)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.84))
            }
        }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(cardShell(cornerRadius: 18))
}
