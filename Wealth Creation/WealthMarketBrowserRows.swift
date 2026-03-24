import SwiftUI

extension MarketsView {
    var instrumentBrowserHeaderRow: some View {
        HStack(spacing: 10) {
            browserHeaderCell("SYMBOL", width: 90, alignment: .leading)
            browserHeaderCell("NAME", width: nil, alignment: .leading)
            browserHeaderCell("TYPE", width: 110, alignment: .leading)
            browserHeaderCell("COUNTRY", width: 130, alignment: .leading)
            browserHeaderCell("REGION", width: 110, alignment: .leading)
            browserHeaderCell("EXCHANGE", width: 110, alignment: .leading)
            browserHeaderCell("CCY", width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 10)
    }

    func browserHeaderCell(_ label: String, width: CGFloat?, alignment: Alignment) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.56))
            .frame(maxWidth: width == nil ? .infinity : width, alignment: alignment)
            .frame(width: width, alignment: alignment)
    }

    func instrumentBrowserRow(_ record: MarketUniverseRecord) -> some View {
        Group {
            if hasDesktopLayout {
                HStack(spacing: 10) {
                    Text(record.symbol)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.cyan)
                        .frame(width: 90, alignment: .leading)

                    Text(record.companyName ?? "Unknown")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)

                    Text(record.assetTypeDisplay)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.orange)
                        .frame(width: 110, alignment: .leading)

                    Text(record.browserCountryLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.86))
                        .frame(width: 130, alignment: .leading)

                    Text(record.browserRegionLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .frame(width: 110, alignment: .leading)

                    Text(record.browserExchangeLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .frame(width: 110, alignment: .leading)

                    Text(record.browserCurrencyLabel)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.green)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 11)
                .background(cardShell(cornerRadius: 15))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(record.symbol)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.cyan)
                        Spacer()
                        Text(record.browserCurrencyLabel)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.green)
                    }

                    Text(record.companyName ?? "Unknown")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack {
                        Text(record.assetTypeDisplay)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.orange)
                        Spacer()
                        Text(record.browserExchangeLabel)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))
                    }

                    HStack {
                        Text(record.browserCountryLabel)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(record.browserRegionLabel)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.62))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 11)
                .background(cardShell(cornerRadius: 15))
            }
        }
    }
}
