import SwiftUI

struct WealthAILiveCompactCard: View {
    let opportunity: Opportunity
    let result: WealthAILiveResult?
    var statusBadgeText: String? = nil
    var secondaryStatusText: String? = nil
    var isExpanded: Bool = false
    var onToggle: () -> Void = {}
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var resultTint: Color {
        result?.aiLiveColor ?? opportunity.cardSignalTint
    }

    private var metricColumns: [GridItem] {
        let minimum = horizontalSizeClass == .compact ? 124.0 : 160.0
        return [GridItem(.adaptive(minimum: minimum), spacing: 8, alignment: .top)]
    }

    private var decisionText: String {
        switch result?.aiLiveDecision {
        case .promote:
            return "READY"
        case .replaceExisting:
            return "REPLACE"
        case .returnToMarket:
            return "WATCH"
        case .reject:
            return "RETURN"
        case nil:
            return opportunity.cardSignalLabel
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(opportunity.symbol)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(opportunity.marketDisplayLabel)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    solidPill(decisionText, color: resultTint, darkText: resultTint != WealthTheme.purple && resultTint != WealthTheme.cyan)
                    Text("#\(opportunity.rank)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.cyan)
                }
            }

            if let statusBadgeText {
                Text(statusBadgeText)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.black.opacity(0.82))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(WealthTheme.yellow.opacity(0.92)))
            }

            if let secondaryStatusText, !secondaryStatusText.isEmpty {
                Text(secondaryStatusText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
                    .lineLimit(isExpanded ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                metricCell(label: "Buy Total", value: WealthFormat.money(opportunity.trueCost), tint: .white)
                metricCell(label: "Live P/L", value: wealthPnLText(opportunity.liveNetProfit), tint: wealthPnLTint(opportunity.liveNetProfit))
                metricCell(label: "Net Exit After Fees", value: WealthFormat.money(opportunity.liveNetExitValue), tint: wealthNetExitTint(netExit: opportunity.liveNetExitValue, buyTotal: opportunity.trueCost))
            }

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                metricCell(label: "Live %", value: wealthPercentMoveText(opportunity.liveMovePercent), tint: wealthPercentMoveTint(opportunity.liveMovePercent))
                metricCell(label: "Fee In", value: WealthFormat.money(opportunity.brokerFee), tint: WealthTheme.orange)
                metricCell(label: "Fee Out", value: WealthFormat.money(opportunity.liveSellFee), tint: WealthTheme.orange)
            }

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                metricCell(label: "Last Refresh", value: opportunity.lastRefreshText, tint: WealthTheme.cyan)
                metricCell(label: "Source Age", value: opportunity.sourceAgeText, tint: WealthTheme.orange)
                metricCell(label: "Next Trade", value: opportunity.nextTradingText, tint: WealthTheme.gold)
            }

            noteBlock(
                label: "Why Picked",
                value: result?.reason ?? opportunity.aiFoundHeadline,
                tint: WealthTheme.cyan
            )

            noteBlock(
                label: "Intel Picked Up",
                value: opportunity.aiLiveIntelSummary,
                tint: WealthTheme.green
            )

            noteBlock(
                label: "Source",
                value: opportunity.sourceSummary,
                tint: .white.opacity(0.92)
            )

            if let sourceFreshnessWarning = opportunity.sourceFreshnessWarning {
                noteBlock(
                    label: "Stale Intel Warning",
                    value: sourceFreshnessWarning,
                    tint: WealthTheme.orange
                )
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                        metricCell(label: "Buy Price", value: WealthFormat.money(opportunity.submittedPrice), tint: .white)
                        metricCell(label: "Live Price", value: WealthFormat.money(opportunity.price), tint: wealthPercentMoveTint(opportunity.liveMovePercent))
                        metricCell(label: "Shield Sell", value: opportunity.shieldExitSummary, tint: WealthTheme.red)
                    }

                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                        metricCell(label: "Profit Lock", value: opportunity.profitLockLabel, tint: WealthTheme.gold)
                        metricCell(
                            label: "Profit Exit",
                            value: "\(WealthFormat.money(opportunity.surgeExitPrice)) (\(wealthPercentMoveText(opportunity.profitLockPercent)))",
                            tint: WealthTheme.gold
                        )
                        metricCell(
                            label: "Surge Protector",
                            value: WealthProtectionSettingsStore.shared.surgeEnabled ? opportunity.surgeOverrideLabel : "OFF",
                            tint: WealthProtectionSettingsStore.shared.surgeEnabled ? WealthTheme.gold : WealthTheme.grey
                        )
                    }

                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                        metricCell(label: "AI Score", value: "\(opportunity.aiScore)", tint: opportunity.scoreTint)
                        metricCell(label: "Conf", value: "\(opportunity.confidence)%", tint: opportunity.confidenceTint)
                        metricCell(label: "Rank", value: "#\(opportunity.rank)", tint: WealthTheme.cyan)
                    }

                    noteBlock(label: "AI Detail", value: opportunity.aiFoundDetail, tint: .white.opacity(0.92))
                    noteBlock(label: "Decision Line", value: opportunity.buyReason, tint: .white.opacity(0.88))
                    noteBlock(label: "Intel Drivers", value: opportunity.intelligenceDriverText, tint: WealthTheme.cyan)
                    noteBlock(label: "Intel Channels", value: opportunity.intelligenceChannelText, tint: WealthTheme.green)
                    noteBlock(label: "Research", value: opportunity.sourceSummary, tint: WealthTheme.green)
                }
            }
        }
        .padding(10)
        .background(listRowShell(cornerRadius: 18, accent: resultTint))
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }

    private func noteBlock(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(tint.opacity(0.82))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(cardShell(cornerRadius: 16))
    }

    private func metricCell(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(sectionGlowShell(cornerRadius: 16, tint: tint))
    }
}
