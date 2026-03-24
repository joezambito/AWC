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
        let band: MarketUniverseLabelBand
        let count: Int

        var id: String {
            band.rawValue
        }
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

    func marketRegionCard(
        region: String,
        entries: [MarketUniverseEntry],
        rawCount: Int,
        phaseLabel: String? = nil
    ) -> some View {
        let regionKey = "world-\(region)"
        let isExpanded = expandedRegions.contains(regionKey)
        let lead = entries.first
        let visibleEntries = visibleRegionEntries(entries)
        let folders = phoneMarketFolders(for: region, entries: visibleEntries)

        return VStack(spacing: 8) {
            Button {
                toggleRegion(regionKey)
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill((lead?.tint ?? WealthTheme.cyan).opacity(0.16))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(lead?.tint ?? WealthTheme.cyan)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(region)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(rawCount) cards available")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(lead?.symbol ?? "--")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(isExpanded ? "TAP TO CLOSE" : "TAP TO OPEN")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: hasDesktopLayout ? 20 : 18, style: .continuous)
                        .fill(Color.black.opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: hasDesktopLayout ? 20 : 18, style: .continuous)
                                .stroke((lead?.tint ?? WealthTheme.cyan).opacity(0.16), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let phaseLabel {
                    marketRegionPhaseRow(phaseLabel, rawCount: rawCount)
                } else {
                    marketRegionSummaryRow(entries: entries, rawCount: rawCount)

                    if folders.isEmpty {
                        ForEach(Array(visibleEntries.prefix(marketRowDetailLimit))) { entry in
                            marketPulseRow(entry)
                        }
                    } else {
                        ForEach(folders) { folder in
                            marketFolderCard(region: region, folder: folder)
                        }
                    }
                }
            }
        }
    }

    private func marketRegionSummaryRow(entries: [MarketUniverseEntry], rawCount: Int) -> some View {
        let sortedCount = entries.filter { $0.aiLabelBand != nil }.count
        let labelCounts = marketRegionLabelCounts(entries: entries)

        return VStack(alignment: .leading, spacing: 8) {
            Text("AI SORTED \(sortedCount)/\(rawCount)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            HStack(spacing: 8) {
                ForEach(labelCounts) { item in
                    marketRegionCountPill(item)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 4)
    }

    private func marketRegionPhaseRow(_ phaseLabel: String, rawCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(rawCount) RAW MARKETS READY")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            Text(phaseLabel)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(WealthTheme.gold)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardShell(cornerRadius: 14))
        }
        .padding(.horizontal, 4)
    }

    private func marketRegionLabelCounts(entries: [MarketUniverseEntry]) -> [MarketRegionLabelCount] {
        MarketUniverseLabelBand.allCases.map { band in
            let count = entries.reduce(into: 0) { total, entry in
                if entry.aiLabelBand == band {
                    total += 1
                }
            }
            return MarketRegionLabelCount(band: band, count: count)
        }
    }

    private func marketRegionCountPill(_ item: MarketRegionLabelCount) -> some View {
        Text("\(item.count) \(item.band.title)")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(item.band.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(item.band.tint.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(item.band.tint.opacity(0.30), lineWidth: 1)
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
        let folderKey = "world-\(region)-\(folder.title)"
        let isExpanded = expandedRegions.contains(folderKey)

        return VStack(spacing: 8) {
            Button {
                toggleRegion(folderKey)
            } label: {
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

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(folder.leadSymbol)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(isExpanded ? "TAP TO CLOSE" : "TAP TO OPEN")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                }
                .padding(10)
                .background(cardShell(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(Array(visibleFolderEntries(folder).prefix(marketRowDetailLimit))) { entry in
                    marketPulseRow(entry)
                }
            }
        }
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

    func marketPulseRow(_ entry: MarketUniverseEntry) -> some View {
        let isExpanded = expandedSymbols.contains(entry.id)

        return Button {
            toggleSymbol(entry.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(entry.tint.opacity(0.16))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: entry.market.contains("CRYPTO") ? "bitcoinsign.circle.fill" : "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(entry.tint)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(entry.tint.opacity(0.28), lineWidth: 1)
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
                            .foregroundColor(.white)
                        Text(entry.confidenceText)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(entry.tint)
                        Text(isExpanded ? "TAP TO CLOSE" : "TAP TO OPEN")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                }

                if isExpanded {
                    HStack(spacing: 8) {
                        marketDetailCell("MARKET", entry.marketDisplayLabel, tint: WealthTheme.purple)
                        marketDetailCell("PRICE", entry.priceText, tint: .white)
                        marketDetailCell("MOVE", entry.changeText, tint: entry.hasQuoteData ? (entry.priceChangePercent >= 0 ? WealthTheme.green : WealthTheme.orange) : WealthTheme.grey)
                    }

                    HStack(spacing: 8) {
                        marketDetailCell("DATA AGE", entry.dataAgeText, tint: WealthTheme.orange)
                        marketDetailCell("NEXT TRADE", entry.nextTradeText, tint: WealthTheme.gold)
                        marketDetailCell("SECTOR", entry.sector, tint: WealthTheme.green)
                    }

                    if let shieldExitPrice = entry.shieldExitPrice,
                       let shieldTriggerPercent = entry.shieldTriggerPercent {
                        HStack(spacing: 8) {
                            marketDetailCell("EXIT PRICE", "\(WealthFormat.money(shieldExitPrice)) (\(wealthPercentMoveText(shieldTriggerPercent)))", tint: WealthTheme.red)
                            marketDetailCell("NEXT TRADE", entry.nextTradeText, tint: WealthTheme.gold)
                            marketDetailCell("SECTOR", entry.sector, tint: WealthTheme.green)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: hasDesktopLayout ? 20 : 18, style: .continuous)
                    .fill(Color.black.opacity(0.20))
                    .overlay(
                        RoundedRectangle(cornerRadius: hasDesktopLayout ? 20 : 18, style: .continuous)
                            .stroke(entry.tint.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func marketDetailCell(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(cardShell(cornerRadius: 14))
    }
}
