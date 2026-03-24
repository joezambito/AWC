import SwiftUI

extension WealthRootView {
    var desktopRootShell: some View {
        NavigationStack {
            GeometryReader { _ in
                HStack(spacing: 16) {
                    desktopSidebar
                        .frame(width: 220, alignment: .top)

                    desktopCenterColumn
                        .frame(maxWidth: .infinity, alignment: .top)

                    desktopSupplementalRail
                        .frame(width: 360, alignment: .top)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 18)
                .background(
                    WealthTheme.background
                        .overlay(screenGlow)
                        .ignoresSafeArea()
                )
            }
            .navigationDestination(item: $selectedOpportunity) { opportunity in
                OpportunityDetailView(opportunity: opportunity)
            }
            .fullScreenCover(item: $selectedHolding) { holding in
                HoldingDetailView(holding: holding)
            }
        }
    }
}
