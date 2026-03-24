import SwiftUI

func cardShell(cornerRadius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(WealthTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WealthTheme.cardStroke, lineWidth: 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.035), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        )
}

func glowPanelShell(cornerRadius: CGFloat, tint: Color = WealthTheme.cyan, secondaryTint: Color = WealthTheme.purple) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(
            LinearGradient(
                colors: [Color.black.opacity(0.32), tint.opacity(0.10), secondaryTint.opacity(0.08), Color.black.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
}

func brandLogoTile(size: CGFloat = 74, cornerRadius: CGFloat = 18) -> some View {
    Image("zulugames_logo")
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
        .padding(size * 0.14)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(WealthTheme.cyan.opacity(0.22), lineWidth: 1)
                )
        )
}

func iconBadge(_ systemImage: String, tint: Color) -> some View {
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(tint.opacity(0.14))
        .frame(width: 68, height: 68)
        .overlay(
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .black))
                .foregroundColor(tint)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1))
}

func solidPill(_ text: String, color: Color, darkText: Bool) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .black, design: .rounded))
        .foregroundColor(darkText ? .black : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color)
        .clipShape(Capsule())
}

func chip(_ text: String, color: Color) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .black, design: .rounded))
        .foregroundColor(color == WealthTheme.grey ? WealthTheme.grey : .black)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color == WealthTheme.grey ? WealthTheme.grey.opacity(0.16) : color)
        .clipShape(Capsule())
}

func infoCell(label: String, value: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.56))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
        Text(value)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(sectionGlowShell(cornerRadius: 16, tint: tint))
}

func footerMetric(title: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.56))
        Text(value)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

func compactSummaryCard(title: String, value: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.58))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        Text(value)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 6)
    .padding(.vertical, 6)
    .background(sectionGlowShell(cornerRadius: 11, tint: tint))
}
