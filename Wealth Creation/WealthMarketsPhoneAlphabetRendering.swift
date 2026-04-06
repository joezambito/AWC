import SwiftUI

extension MarketsView {
    var phoneWorldMarketsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            phoneMarketIndexPanel
            phoneMarketLetterPanel
            phoneSelectedMarketBucketPanel
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 18, tint: WealthTheme.green, secondaryTint: WealthTheme.cyan))
    }

    private var phoneMarketIndexPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MARKET INDEX")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.72))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(phoneMarketSummaries) { item in
                    let isSelected = item.code == selectedPhoneMarketSummary?.code
                    Button {
                        selectPhoneMarket(item.code)
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill((isSelected ? WealthTheme.cyan : WealthTheme.white).opacity(isSelected ? 0.18 : 0.08))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(isSelected ? WealthTheme.cyan : .white)
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("\(item.count) shares")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(isSelected ? WealthTheme.cyan : WealthTheme.grey)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(cardShell(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var phoneMarketLetterPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LETTER BUCKETS")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                Spacer()
                if let summary = selectedPhoneMarketSummary, summary.style == .singleLetter {
                    solidPill("SINGLE LETTER", color: WealthTheme.orange, darkText: true)
                } else {
                    solidPill("GROUPED", color: WealthTheme.green, darkText: true)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedPhoneMarketBuckets) { bucket in
                        let count = phoneMarketBucketIDCache[selectedPhoneMarketCode]?[bucket.id]?.count ?? 0
                        let isSelected = bucket.id == selectedPhoneLetterBucketDefinition?.id

                        Button {
                            selectPhoneLetterBucket(bucket.id)
                        } label: {
                            VStack(spacing: 4) {
                                Text(bucket.title)
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(isSelected ? .black : .white)
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(isSelected ? .black.opacity(0.72) : WealthTheme.grey)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? WealthTheme.cyan : Color.white.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var phoneSelectedMarketBucketPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\((selectedPhoneMarketSummary?.title ?? "--")) · \((selectedPhoneLetterBucketDefinition?.title ?? "--"))")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Page \(selectedPhoneBucketPage + 1) of \(selectedPhoneBucketPageCount) · \(selectedPhoneVisibleEntries.count) loaded")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        shiftPhoneBucketPage(-1)
                    } label: {
                        Text("PREV")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selectedPhoneBucketPage > 0 ? WealthTheme.gold : WealthTheme.grey.opacity(0.4))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPhoneBucketPage == 0)

                    Button {
                        shiftPhoneBucketPage(1)
                    } label: {
                        Text("NEXT")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selectedPhoneBucketPage + 1 < selectedPhoneBucketPageCount ? WealthTheme.cyan : WealthTheme.grey.opacity(0.4))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPhoneBucketPage + 1 >= selectedPhoneBucketPageCount)
                }
            }

            if selectedPhoneVisibleEntries.isEmpty {
                Text("No shares are currently visible in this market bucket.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardShell(cornerRadius: 16))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(selectedPhoneVisibleEntries) { entry in
                        marketPulseRow(entry)
                    }
                }
            }
        }
    }
}
