import SwiftUI

extension MarketsView {
    var browserSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(WealthTheme.cyan)

            TextField("Search symbol, name, exchange or country", text: $browserStore.searchText)
                .awcHostFieldInputBehavior()
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if !browserStore.searchText.isEmpty {
                Button {
                    browserStore.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.72))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(cardShell(cornerRadius: 16))
    }

    var instrumentBrowserFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                browserFilterMenu("TYPE", selection: $browserStore.selectedAssetType, options: assetTypeOptions)
                browserFilterMenu("REGION", selection: $browserStore.selectedRegion, options: regionOptions)
                browserFilterMenu("COUNTRY", selection: $browserStore.selectedCountry, options: countryOptions)
                browserFilterMenu("EXCHANGE", selection: $browserStore.selectedExchange, options: exchangeOptions)
                browserFilterMenu("CCY", selection: $browserStore.selectedCurrency, options: currencyOptions)
            }
            .padding(.vertical, 2)
        }
    }

    func browserFilterMenu(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    Text(option)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.56))
                Text(selection.wrappedValue)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(WealthTheme.cyan)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(cardShell(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }

    var browserPaginationRow: some View {
        HStack(spacing: 10) {
            Button {
                browserStore.page = max(browserStore.page - 1, 0)
            } label: {
                Text("PREV")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(clampedBrowserPage == 0 ? .white.opacity(0.4) : .black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(clampedBrowserPage == 0 ? Color.white.opacity(0.06) : WealthTheme.cyan)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(clampedBrowserPage == 0)

            Text("PAGE \(clampedBrowserPage + 1) / \(browserPageCount)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.84))

            Button {
                browserStore.page = min(browserStore.page + 1, browserPageCount - 1)
            } label: {
                Text("NEXT")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(clampedBrowserPage >= browserPageCount - 1 ? .white.opacity(0.4) : .black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(clampedBrowserPage >= browserPageCount - 1 ? Color.white.opacity(0.06) : WealthTheme.green)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(clampedBrowserPage >= browserPageCount - 1)

            Spacer()
        }
    }

    func browserStatusCard(title: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(tint)
            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.84))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionGlowShell(cornerRadius: 16, tint: tint))
    }
}
