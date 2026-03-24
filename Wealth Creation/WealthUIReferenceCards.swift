import SwiftUI

func dashboardMetricCard(title: String, value: String, accent: Color, tag: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.74))
            if let tag {
                Text(tag)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.95))
                    .clipShape(Capsule())
            }
        }
        Text(value)
            .font(.system(size: 19, weight: .black, design: .rounded))
            .foregroundColor(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 11)
    .background(cardShell(cornerRadius: 16))
}

func listRowShell(cornerRadius: CGFloat, accent: Color, edgeGlow: Bool = true) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(
            LinearGradient(
                colors: [Color.black.opacity(0.34), accent.opacity(0.08), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .overlay(
            Group {
                if edgeGlow {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.42), lineWidth: 4)
                        .padding(.leading, -12)
                }
            },
            alignment: .leading
        )
}

func sectionGlowShell(cornerRadius: CGFloat, tint: Color) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(
            LinearGradient(
                colors: [Color.black.opacity(0.30), tint.opacity(0.08), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
}

func bigSummaryCard(title: String, value: String, caption: String = "AUD", accent: Color = .white) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.58))
        Text(value)
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundColor(accent)
        Text(caption)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.6))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(glowPanelShell(cornerRadius: 22, tint: accent, secondaryTint: WealthTheme.purple))
}

func balanceReferenceCard(title: String, value: String, accent: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.58))
        Text(value)
            .font(.system(size: 21, weight: .black, design: .rounded))
            .foregroundColor(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        Text("READ ONLY")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.54))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(glowPanelShell(cornerRadius: 22, tint: accent, secondaryTint: WealthTheme.cyan))
}

func miniReferenceCard(title: String, value: String, accent: Color, tag: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
            if let tag {
                Text(tag)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.95))
                    .clipShape(Capsule())
            }
        }
        Text(value)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundColor(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(sectionGlowShell(cornerRadius: 18, tint: accent))
}

func capitalActionButton(title: String, tint: Color, darkText: Bool = true, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(darkText ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint)
            )
    }
    .buttonStyle(.plain)
}
