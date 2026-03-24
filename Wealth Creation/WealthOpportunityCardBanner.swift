import SwiftUI

struct OpportunityCardBannerView: View {
    let opportunity: Opportunity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let recoveryLabel = opportunity.recoverySetupLabel {
                bannerRow("WHY BUY", recoveryLabel, tint: opportunity.recoverySetupTint)
            }

            bannerRow("PRED HOLD", opportunity.predictedHoldText, tint: WealthTheme.purple)
        }
    }

    private func bannerRow(_ label: String, _ value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(tint.opacity(0.9))
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            cardShell(cornerRadius: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.30), lineWidth: 1)
                )
        )
    }
}
