import SwiftUI

extension OpportunityCard {
    var expandedDetails: some View {
        OpportunityCardExpandedDetailsView(opportunity: opportunity)
    }
}

struct OpportunityCardCompactCell: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(tint.opacity(0.82))
                .lineLimit(1)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .background(
            cardShell(cornerRadius: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.32), lineWidth: 1)
                )
        )
    }
}
