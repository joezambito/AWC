import SwiftUI

extension WealthLockView {
    var badge: some View {
        Text("SECURE ACCESS")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(WealthTheme.cyan)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(WealthTheme.cyan.opacity(0.12))
                    .overlay(Capsule().stroke(WealthTheme.cyan.opacity(0.26), lineWidth: 0.8))
            )
    }

    var logo: some View {
        Image("zulugames_logo")
            .resizable()
            .scaledToFit()
            .frame(width: 160)
            .background(Color.red)
    }

    var titleBlock: some View {
        VStack(spacing: 6) {
            Text("AUTONOMOUS WEALTH")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text("GENERATION")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text("Use Face ID or enter your 6-digit passcode.")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    var messageView: some View {
        if !message.isEmpty {
            Text(message)
                .font(.caption)
                .foregroundColor(.yellow)
        }
    }

    var helperText: some View {
        Text("Forgot passcode? Verify with Face ID or your device passcode to reset it.")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(WealthTheme.grey)
            .multilineTextAlignment(.center)
    }

    var actions: some View {
        HStack(spacing: 10) {
            actionButton(title: "Forgot Passcode", tint: WealthTheme.orange) {
                showResetPasscode = true
            }

            actionButton(title: "Change Passcode", tint: WealthTheme.cyan) {
                showChangePasscode = true
            }
        }
    }

    func actionButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color(red: 0.70, green: 0.84, blue: 0.94).opacity(0.18),
                        Color(red: 0.82, green: 0.74, blue: 0.96).opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color(red: 0.42, green: 0.82, blue: 0.96).opacity(0.34), lineWidth: 1)
            )
    }

    var lockBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.38, green: 0.44, blue: 0.53),
                Color(red: 0.64, green: 0.82, blue: 0.94),
                Color(red: 0.74, green: 0.66, blue: 0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [Color.white.opacity(0.28), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 320
            )
        )
        .overlay(
            RadialGradient(
                colors: [Color.white.opacity(0.16), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
        )
        .ignoresSafeArea()
    }
}

struct WealthPasscodeDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < count ? WealthTheme.cyan : Color.white.opacity(0.18))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 6)
    }
}
