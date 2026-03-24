import SwiftUI

struct OpportunityCard: View {
    let opportunity: Opportunity
    var isExpanded: Bool = false
    var onToggle: () -> Void = {}
    var allowsInlineToggle: Bool = false
    var usesDenseLayout: Bool = false
    var usesDenseCollapsedState: Bool = false

    var body: some View {
        let isDense = usesDenseLayout || (usesDenseCollapsedState && !isExpanded)
        let content = VStack(alignment: .leading, spacing: isDense ? 8 : 10) {
            compactHeader
            compactHighlights
            predictedHoldBanner

            if isExpanded {
                expandedDetails
            } else {
                collapsedDetails
            }
        }
        .padding(isDense ? 10 : 12)
        .background(cardBackground)
        .padding(.horizontal, isDense ? 10 : 12)

        if allowsInlineToggle {
            content
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        onToggle()
                    }
                }
        } else {
            content
        }
    }

    private var cardBackground: some View {
        listRowShell(cornerRadius: 20, accent: opportunity.cardSignalTint)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(opportunity.sessionState.color.opacity(0.22), lineWidth: 1)
            )
    }
}
