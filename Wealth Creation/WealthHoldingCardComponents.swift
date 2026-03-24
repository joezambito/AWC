import SwiftUI

func cleanHoldingAIText(_ text: String) -> String {
    guard !text.isEmpty else { return text }

    return text
        .replacingOccurrences(of: "The brain", with: "The AI")
        .replacingOccurrences(of: "the brain", with: "the AI")
        .replacingOccurrences(of: "Brain", with: "AI")
        .replacingOccurrences(of: "brain", with: "AI")
}

func compactHoldingMetricView(_ title: String, _ value: String, tint: Color = .white) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.56))
            .lineLimit(1)
            .minimumScaleFactor(0.58)

        Text(value)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.54)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
            )
    )
}

func compactHoldingBadgeView(_ text: String, color: Color) -> some View {
    Text(text)
        .font(.system(size: 9, weight: .black, design: .rounded))
        .foregroundColor(color == WealthTheme.green || color == WealthTheme.gold ? .black : color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color == WealthTheme.green || color == WealthTheme.gold ? color : color.opacity(0.14)))
}

func compactHoldingNoteView(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(WealthTheme.gold)

        Text(cleanHoldingAIText(value))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(2)
            .lineLimit(5)
    }
    .padding(10)
    .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WealthTheme.gold.opacity(0.18), lineWidth: 0.8)
            )
    )
}

func compactHoldingSectionView(
    title: String,
    rows: [[(label: String, value: String, tint: Color)]]
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.48))

        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            HStack(spacing: 8) {
                ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                    compactHoldingMetricView(item.label, item.value, tint: item.tint)
                }
            }
        }
    }
}

func aiNarrativeCellView(label: String, value: String, tint: Color = .white) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(tint.opacity(0.88))

        Text(cleanHoldingAIText(value))
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(1)
            .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 0.8)
            )
    )
}

struct HoldingStatusIcons: View {
    let shieldVisible: Bool
    let surgeEnabled: Bool

    var body: some View {
        HStack(spacing: 6) {
            if shieldVisible {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(WealthTheme.orange)
            }
            if surgeEnabled {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(WealthTheme.gold)
            }
        }
    }
}
