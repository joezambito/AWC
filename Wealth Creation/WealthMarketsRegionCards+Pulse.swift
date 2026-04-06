import SwiftUI

extension MarketsView {
    private struct MarketEntryFolder: Identifiable {
        let id: String
        let title: String
        let entries: [MarketUniverseEntry]
        let tint: Color

        var leadSymbol: String {
            entries.first?.symbol ?? "--"
        }
    }

    private struct MarketRegionLabelCount: Identifiable {
        let id: String
        let title: String
        let count: Int
        let tint: Color
    }

    private var marketRowDetailLimit: Int {
        hasDesktopLayout ? 999 : 40
    }

    private var phoneFolderThreshold: Int {
        36
    }

    private var phoneFolderBatchSize: Int {
        36
    }
    // MARK: Region Card Layout
    // Safe manual tweak area:
    // - outer VStack spacing
    // - header HStack spacing
    // - icon size and corner radius
    // - title/subtitle font sizes
    // - header padding
    // - card stroke opacity / corner radius
    func marketRegionCard(
        summary: MarketRegionBoardSummary,
        phaseLabel: String? = nil
    ) -> some View {
        let labelCounts = marketRegionLabelCounts(summary: summary)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(summary.accentTint.opacity(0.16))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(summary.accentTint)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.region)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(summary.rawCount) cards available")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(summary.state.canTradeNow ? "OPEN" : "CLOSED")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(summary.state.color)
                    if let phaseLabel {
                        Text(phaseLabel)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.gold)
                    }
                }
            }

            HStack(spacing: 8) {
                marketCollapsedSummaryRow(labelCounts)
            }
        }
        .contentShape(Rectangle())
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: hasDesktopLayout ? 20 : 18, style: .continuous)
                .fill(Color.black.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: hasDesktopLayout ? 20 : 18, style: .continuous)
                        .stroke(summary.accentTint.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func marketCollapsedSummaryRow(_ labelCounts: [MarketRegionLabelCount]) -> some View {
        return HStack(spacing: 8) {
            ForEach(labelCounts) { item in
                marketRegionCountPill(item)
            }
            Spacer(minLength: 0)
        }
    }

    private func marketRegionLabelCounts(summary: MarketRegionBoardSummary) -> [MarketRegionLabelCount] {
        [
            MarketRegionLabelCount(id: "green", title: "GREEN", count: summary.greenCount, tint: WealthTheme.green),
            MarketRegionLabelCount(id: "blue", title: "BLUE", count: summary.blueCount, tint: WealthTheme.blue),
            MarketRegionLabelCount(id: "purple", title: "PURPLE", count: summary.purpleCount, tint: WealthTheme.purple),
            MarketRegionLabelCount(id: "red", title: "RED", count: summary.redCount, tint: WealthTheme.red),
            MarketRegionLabelCount(id: "grey", title: "GREY", count: summary.greyCount, tint: WealthTheme.grey)
        ]
    }

    private func marketRegionCountPill(_ item: MarketRegionLabelCount) -> some View {
        VStack(spacing: 2) {
            Text(item.title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(item.tint.opacity(0.9))
            Text("\(item.count)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(item.tint)
        }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(item.tint.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(item.tint.opacity(0.30), lineWidth: 1)
            )
    }

    private func phoneMarketFolders(for region: String, entries: [MarketUniverseEntry]) -> [MarketEntryFolder] {
        guard !hasDesktopLayout, entries.count > phoneFolderThreshold else { return [] }

        let definitions = folderBands(for: region)

        var grouped: [[MarketUniverseEntry]] = Array(repeating: [], count: definitions.count)

        for entry in entries {
            let first = entry.symbol.first ?? "#"
            if let index = definitions.dropLast().firstIndex(where: { $0.matcher(first) }) {
                grouped[index].append(entry)
            } else {
                grouped[definitions.count - 1].append(entry)
            }
        }

        return zip(definitions.indices, definitions).compactMap { index, definition in
            let folderEntries = grouped[index]
            guard !folderEntries.isEmpty else { return nil }
            return MarketEntryFolder(
                id: "folder-\(region)-\(definition.title)",
                title: definition.title,
                entries: folderEntries,
                tint: folderEntries.first?.tint ?? WealthTheme.cyan
            )
        }
    }

    private func folderBands(for region: String) -> [(title: String, matcher: (Character) -> Bool)] {
        if region == "UNKNOWN" {
            return [
                ("0-9", { $0.isNumber }),
                ("A-B", { "AB".contains($0.uppercased()) }),
                ("C-D", { "CD".contains($0.uppercased()) }),
                ("E-F", { "EF".contains($0.uppercased()) }),
                ("G-H", { "GH".contains($0.uppercased()) }),
                ("I-J", { "IJ".contains($0.uppercased()) }),
                ("K-L", { "KL".contains($0.uppercased()) }),
                ("M-N", { "MN".contains($0.uppercased()) }),
                ("O-P", { "OP".contains($0.uppercased()) }),
                ("Q-R", { "QR".contains($0.uppercased()) }),
                ("S-T", { "ST".contains($0.uppercased()) }),
                ("U-V", { "UV".contains($0.uppercased()) }),
                ("W-Z", { "WXYZ".contains($0.uppercased()) }),
                ("OTHER", { _ in false })
            ]
        }

        return [
            ("0-9", { $0.isNumber }),
            ("A-B", { "AB".contains($0.uppercased()) }),
            ("C-D", { "CD".contains($0.uppercased()) }),
            ("E-F", { "EF".contains($0.uppercased()) }),
            ("G-H", { "GH".contains($0.uppercased()) }),
            ("I-J", { "IJ".contains($0.uppercased()) }),
            ("K-L", { "KL".contains($0.uppercased()) }),
            ("M-N", { "MN".contains($0.uppercased()) }),
            ("O-P", { "OP".contains($0.uppercased()) }),
            ("Q-R", { "QR".contains($0.uppercased()) }),
            ("S-T", { "ST".contains($0.uppercased()) }),
            ("U-V", { "UV".contains($0.uppercased()) }),
            ("W-Z", { "WXYZ".contains($0.uppercased()) }),
            ("OTHER", { _ in false })
        ]
    }

    private func marketFolderCard(region: String, folder: MarketEntryFolder) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(folder.tint.opacity(0.16))
                .frame(width: 38, height: 38)
                .overlay(
                    Text(folder.title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(folder.tint)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("\(folder.entries.count) cards")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }

            Spacer()

            Text(folder.leadSymbol)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(10)
        .background(cardShell(cornerRadius: 16))
    }

    private func visibleRegionEntries(_ entries: [MarketUniverseEntry]) -> [MarketUniverseEntry] {
        guard !hasDesktopLayout else { return entries }
        guard entries.count > marketRowDetailLimit else { return entries }

        let batchCount = max(1, Int(ceil(Double(entries.count) / Double(marketRowDetailLimit))))
        let batchIndex = marketFeedScanBatchIndex % batchCount
        let start = batchIndex * marketRowDetailLimit
        let end = min(start + marketRowDetailLimit, entries.count)

        guard start < end else { return Array(entries.prefix(marketRowDetailLimit)) }
        return Array(entries[start..<end])
    }

    private func visibleFolderEntries(_ folder: MarketEntryFolder) -> [MarketUniverseEntry] {
        guard !hasDesktopLayout else { return folder.entries }
        guard folder.entries.count > phoneFolderBatchSize else { return folder.entries }

        let batchCount = max(1, Int(ceil(Double(folder.entries.count) / Double(phoneFolderBatchSize))))
        let batchIndex = marketFeedScanBatchIndex % batchCount
        let start = batchIndex * phoneFolderBatchSize
        let end = min(start + phoneFolderBatchSize, folder.entries.count)

        guard start < end else { return Array(folder.entries.prefix(phoneFolderBatchSize)) }
        return Array(folder.entries[start..<end])
    }

    private func visibleBucketEntries(_ entries: [MarketUniverseEntry]) -> [MarketUniverseEntry] {
        guard !hasDesktopLayout else { return entries }
        guard entries.count > phoneFolderBatchSize else { return entries }

        let batchCount = max(1, Int(ceil(Double(entries.count) / Double(phoneFolderBatchSize))))
        let batchIndex = marketFeedScanBatchIndex % batchCount
        let start = batchIndex * phoneFolderBatchSize
        let end = min(start + phoneFolderBatchSize, entries.count)

        guard start < end else { return Array(entries.prefix(phoneFolderBatchSize)) }
        return Array(entries[start..<end])
    }

    private func marketPriceChangeTint(for entry: MarketUniverseEntry) -> Color {
        guard entry.hasQuoteData else { return WealthTheme.grey }
        if abs(entry.priceChangePercent) < 0.05 { return WealthTheme.orange }
        return entry.priceChangePercent > 0 ? WealthTheme.green : WealthTheme.red
    }

    private func marketQuoteStatusTagText(for entry: MarketUniverseEntry) -> String {
        let status = entry.statusText.uppercased()
        if status.contains("NO PERMISSION") { return "NO PERMISSION" }
        if entry.isDelayed || status.contains("DELAYED") { return "DELAYED" }
        if entry.hasQuoteData || status.contains("LIVE") { return "LIVE" }
        return "PENDING"
    }

    private func marketQuoteStatusTagTint(for entry: MarketUniverseEntry) -> Color {
        let label = marketQuoteStatusTagText(for: entry)
        switch label {
        case "LIVE":
            return WealthTheme.green
        case "DELAYED":
            return WealthTheme.orange
        case "NO PERMISSION":
            return WealthTheme.red
        default:
            return WealthTheme.grey
        }
    }

    // MARK: Compact Share Row Layout
    // Safe manual tweak area:
    // - row HStack spacing
    // - symbol/market/value font sizes
    // - row horizontal/vertical padding
    // - card shell corner radius
    func marketCompactShareRow(_ entry: MarketUniverseEntry) -> some View {
        let detailOpportunity = marketDetailOpportunity(for: entry)
        let expansionKey = entry.id
        let isExpanded = expandedSymbols.contains(expansionKey)

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                guard detailOpportunity != nil else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    toggleSymbol(expansionKey)
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.symbol)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(entry.marketDisplayLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(entry.priceText)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(entry.hasQuoteData ? .white : WealthTheme.grey)
                        Text(entry.changeText)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(marketPriceChangeTint(for: entry))
                        Text(marketQuoteStatusTagText(for: entry))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(marketQuoteStatusTagTint(for: entry))
                    }
                    .frame(width: 92, alignment: .trailing)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(entry.aiScoreText)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(entry.tint)
                        Text(entry.confidenceText)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(entry.tint)
                    }
                    .frame(width: 74, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(cardShell(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            if isExpanded, let opportunity = detailOpportunity {
                marketCompactDetail(opportunity)
            }
        }
    }

    private func marketDetailOpportunity(for entry: MarketUniverseEntry) -> Opportunity? {
        let lookupKey = entry.backingOpportunityKey
            ?? WealthOpportunityLaneRules.laneKey(symbol: entry.symbol, market: entry.market)

        if let exact = marketLaneOpportunities.first(where: {
            WealthOpportunityLaneRules.laneKey($0) == lookupKey
        }) {
            return exact
        }

        return marketOpportunityLookup[lookupKey]
    }

    private func marketCompactDetail(_ opportunity: Opportunity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MARKET RANK")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WealthTheme.cyan.opacity(0.78))
                Text("#\(max(opportunity.rank, 1))")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(WealthTheme.cyan)
            }

            marketCompactDetailRow("BUY PRICE", WealthFormat.money(opportunity.submittedPrice), tint: .white)
            marketCompactDetailRow("CURRENT P/L", wealthPnLText(opportunity.liveNetProfit), tint: wealthPnLTint(opportunity.liveNetProfit))
            marketCompactDetailRow("AI SCORE", "\(opportunity.aiScore)", tint: opportunity.scoreTint)
            marketCompactDetailRow("CONFIDENCE", "\(opportunity.confidence)%", tint: opportunity.confidenceTint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(cardShell(cornerRadius: 16))
    }

    private func marketCompactDetailRow(_ label: String, _ value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(tint.opacity(0.82))
                .frame(width: 94, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func marketPulseRow(_ entry: MarketUniverseEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(entry.backgroundTint.opacity(entry.hasFreshData ? 0.16 : 0.28))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: entry.market.contains("CRYPTO") ? "bitcoinsign.circle.fill" : "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(entry.tint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(entry.borderTint.opacity(0.28), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.symbol)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(entry.marketDisplayLabel)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    Text(entry.statusText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(entry.tint)
                        .lineLimit(1)
                    Text(entry.whyText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.priceText)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(entry.hasQuoteData ? .white : WealthTheme.grey)
                    Text(entry.aiScoreText)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(entry.tint)
                    Text(entry.confidenceText)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(entry.tint)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: hasDesktopLayout ? 20 : 18, style: .continuous)
                .fill(entry.backgroundTint.opacity(entry.hasFreshData ? 0.16 : 0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: hasDesktopLayout ? 20 : 18, style: .continuous)
                        .stroke(entry.borderTint.opacity(0.22), lineWidth: 1)
                )
        )
    }

}
