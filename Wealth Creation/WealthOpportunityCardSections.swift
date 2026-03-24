import SwiftUI

extension OpportunityCard {
    var compactHeader: some View {
        OpportunityCardHeaderView(opportunity: opportunity, isExpanded: isExpanded)
    }

    var compactHighlights: some View {
        OpportunityCardHighlightsView(opportunity: opportunity)
    }

    var predictedHoldBanner: some View {
        OpportunityCardBannerView(opportunity: opportunity)
    }
}
