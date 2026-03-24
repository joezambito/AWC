import SwiftUI

struct ActivitySummaryBanner: View {
    let title: String
    let message: String
    let tint: Color
    let badgeCount: Int
    let moments: [NotificationMomentViewModel]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: badgeCount > 0 ? "bolt.badge.clock.fill" : "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(tint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(0.28), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(tint)
                    Text(message)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.76))
                        .lineLimit(2)
                }

                Spacer()

                solidPill(badgeCount > 0 ? "\(badgeCount) NEW" : "CLEAR", color: badgeCount > 0 ? tint : WealthTheme.green, darkText: true)
            }

            if !moments.isEmpty {
                VStack(spacing: 6) {
                    ForEach(moments.prefix(2)) { moment in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(moment.tint)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(moment.title)
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundColor(moment.tint == WealthTheme.white ? .white : moment.tint)
                                Text(moment.detail)
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.035))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(moment.tint.opacity(0.16), lineWidth: 0.8)
                                )
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(cardShell(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
