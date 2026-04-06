import SwiftUI

struct OpportunityCard: View {
    let opportunity: Opportunity
    var accentTint: Color? = nil
    var statusBadgeText: String? = nil
    var secondaryStatusText: String? = nil
    var isExpanded: Bool = false
    var onToggle: () -> Void = {}
    var allowsInlineToggle: Bool = false
    var usesDenseLayout: Bool = false
    var usesDenseCollapsedState: Bool = false

    var body: some View {
        let isDense = usesDenseLayout || (usesDenseCollapsedState && !isExpanded)
        // MARK: Opportunity Card Layout
        // Safe manual tweak area:
        // - card VStack spacing
        // - outer card padding
        // - horizontal inset
        // - card corner radius
        let content = VStack(alignment: .leading, spacing: isDense ? 8 : 10) {
            compactHeader
            if let statusBadgeText {
                activityReturnBadge(statusBadgeText)
            }
            if let secondaryStatusText, !secondaryStatusText.isEmpty {
                Text(secondaryStatusText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    // MARK: Opportunity Card Status Area
    // Safe manual tweak area:
    // - badge font size
    // - badge padding
    // - capsule shape feel
    private func activityReturnBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(.black.opacity(0.82))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(WealthTheme.yellow.opacity(0.92))
            )
    }
}
