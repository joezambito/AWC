import SwiftUI

func wealthSystemHeroPanel(title: String, subtitle: String, icon: String, badge: String?, badgeColor: Color) -> some View {
    HStack {
        HStack(spacing: 12) {
            iconBadge(icon, tint: WealthTheme.cyan)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }
        }
        Spacer()
        if let badge {
            solidPill(badge, color: badgeColor, darkText: badgeColor == WealthTheme.green || badgeColor == WealthTheme.cyan)
        }
    }
    .padding(14)
    .background(glowPanelShell(cornerRadius: 26, tint: badgeColor, secondaryTint: WealthTheme.purple))
}

func wealthSystemTuningStepper(title: String, subtitle: String, valueText: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
    HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
        }
        Spacer()
        Button(action: decrement) {
            wealthSystemTuningButtonLabel("-")
        }
        Text(valueText)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundColor(WealthTheme.cyan)
            .frame(width: 62)
        Button(action: increment) {
            wealthSystemTuningButtonLabel("+")
        }
    }
    .padding(14)
    .background(sectionGlowShell(cornerRadius: 18, tint: WealthTheme.cyan))
}

func wealthSystemTuningButtonLabel(_ symbol: String) -> some View {
    Text(symbol)
        .font(.system(size: 20, weight: .black, design: .rounded))
        .foregroundColor(.white)
        .frame(width: 48, height: 48)
        .background(sectionGlowShell(cornerRadius: 14, tint: WealthTheme.cyan))
}

func wealthSystemTuningStatCard(title: String, value: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.55))
        Text(value)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(sectionGlowShell(cornerRadius: 18, tint: tint))
}

func wealthSystemSyncActionButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(WealthTheme.cyan)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
}

func wealthSystemToggleCard(title: String, subtitle: String, tint: Color, isOn: Binding<Bool>) -> some View {
    HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
        }
        Spacer()
        Toggle("", isOn: isOn)
            .tint(tint)
            .labelsHidden()
    }
    .padding(16)
    .background(glowPanelShell(cornerRadius: 24, tint: tint, secondaryTint: WealthTheme.cyan))
}

func wealthSystemMinutesField(value: Binding<Double>, tint: Color) -> some View {
    HStack(spacing: 10) {
        TextField("", value: value, format: .number)
            .keyboardType(.decimalPad)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .multilineTextAlignment(.center)
        Text("min")
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundColor(tint)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .background(cardShell(cornerRadius: 18))
}
