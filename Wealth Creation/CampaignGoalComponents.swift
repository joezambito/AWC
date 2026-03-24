import SwiftUI

func desktopGoalPulse(title: String, value: String, subtitle: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.6))
        Text(value)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .minimumScaleFactor(0.8)
        Text(subtitle)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(WealthTheme.grey)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(glowPanelShell(cornerRadius: 20, tint: tint, secondaryTint: WealthTheme.purple))
    .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(tint.opacity(0.16), lineWidth: 1)
    )
}

struct GoalCard: View {
    let title: String
    let subtitle: String
    let targetTitle: String
    @Binding var targetValue: Double
    let timeframeTitle: String?
    var timeframeValue: Binding<Int>?
    let valueTitle: String
    let value: Double
    let remaining: Double
    let accent: Color

    private var performanceTint: Color {
        wealthPnLTint(value)
    }

    private var remainingTint: Color {
        remaining > 0 ? WealthTheme.red : WealthTheme.green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(accent)
                Text(subtitle)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(targetTitle)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                numberField(value: $targetValue)
            }

            if let timeframeTitle, let timeframeValue {
                VStack(alignment: .leading, spacing: 8) {
                    Text(timeframeTitle)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    integerField(value: timeframeValue)
                }
            }

            HStack(spacing: 12) {
                goalMetric(title: valueTitle, value: WealthFormat.money(value), tint: performanceTint)
                goalMetric(title: "REMAINING", value: WealthFormat.money(remaining), tint: remainingTint)
            }

            let target = max(targetValue, 1)
            let rawProgress = target > 0 ? (value / target) : 0
            let progress = rawProgress.isFinite ? min(1, max(0, rawProgress)) : 0

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PROGRESS")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(progress >= 1 ? WealthTheme.green : accent)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(progress >= 1 ? WealthTheme.green : accent)
                            .frame(width: max(0, proxy.size.width * progress))
                    }
                }
                .frame(height: 12)
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 18, tint: accent, secondaryTint: WealthTheme.cyan))
    }

    private func numberField(value: Binding<Double>) -> some View {
        TextField("", value: value, format: .number)
            .keyboardType(.decimalPad)
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(sectionGlowShell(cornerRadius: 16, tint: accent))
    }

    private func integerField(value: Binding<Int>) -> some View {
        TextField("", value: value, format: .number)
            .keyboardType(.numberPad)
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(sectionGlowShell(cornerRadius: 16, tint: accent))
    }
}
