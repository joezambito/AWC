import SwiftUI

func sectionShell(title: String, subtitle: String, trailing: String? = nil) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
        }
        Spacer()
        if let trailing {
            solidPill(trailing, color: WealthTheme.red, darkText: false)
        }
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 10)
    .background(glowPanelShell(cornerRadius: 20, tint: WealthTheme.cyan, secondaryTint: WealthTheme.purple))
    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(WealthTheme.cyan.opacity(0.16), lineWidth: 0.9))
}

func segmentBar(options: [String], selected: String, activeColor: Color, darkWhenSelected: Bool = false, onSelect: @escaping (String) -> Void) -> some View {
    HStack(spacing: 8) {
        ForEach(options, id: \.self) { option in
            Button {
                onSelect(option)
            } label: {
                Text(option)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(selected == option ? (darkWhenSelected ? .black : .white) : .white.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selected == option ? activeColor : Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selected == option ? activeColor.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
    .padding(8)
    .background(cardShell(cornerRadius: 20))
}

func goalMetric(title: String, value: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.58))
        Text(value)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(sectionGlowShell(cornerRadius: 18, tint: tint))
}
