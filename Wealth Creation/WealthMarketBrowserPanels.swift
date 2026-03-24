import SwiftUI

extension MarketsView {
    var instrumentBrowserPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("INSTRUMENT BROWSER")
                        .font(.system(size: hasDesktopLayout ? 16 : 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Normalized global universe with search, filters and paged browsing")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()
                solidPill(universeStore.sourceLabel, color: universeStore.errorMessage == nil ? WealthTheme.blue : WealthTheme.red, darkText: false)
            }

            browserSearchField
            instrumentBrowserFilters

            if let warningMessage = universeStore.warningMessage {
                browserStatusCard(title: "CSV FALLBACK", detail: warningMessage, tint: WealthTheme.orange)
            }

            if universeStore.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(WealthTheme.cyan)
                    Text("Loading normalized market universe...")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.86))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardShell(cornerRadius: 16))
            } else if let errorMessage = universeStore.errorMessage, universeStore.records.isEmpty {
                browserStatusCard(title: "LOAD ERROR", detail: errorMessage, tint: WealthTheme.red)
            } else {
                HStack {
                    Text(browserResultsLabel)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.cyan)
                    Spacer()
                    Text("\(universeStore.records.count) ACTIVE FILE ROWS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                }

                if hasDesktopLayout {
                    instrumentBrowserHeaderRow
                }

                LazyVStack(spacing: 8) {
                    if pagedBrowserRecords.isEmpty {
                        browserStatusCard(title: "NO MATCHES", detail: "The current search and filter combination returned no instruments.", tint: WealthTheme.grey)
                    } else {
                        ForEach(pagedBrowserRecords) { record in
                            instrumentBrowserRow(record)
                        }
                    }
                }

                browserPaginationRow
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glowPanelShell(cornerRadius: hasDesktopLayout ? 22 : 18, tint: WealthTheme.purple, secondaryTint: WealthTheme.cyan))
    }
}
