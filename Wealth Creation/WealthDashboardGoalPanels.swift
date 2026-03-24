import SwiftUI

struct WealthDashboardGoalCard: View {
    let title: String
    let progress: GoalProgress
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
                Spacer()
                Text("\(Int(progress.percent * 100))%")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(tint)
            }

            Text(WealthFormat.money(progress.actual))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            let safePercent = progress.percent.isFinite ? min(1, max(0, progress.percent)) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)

                Capsule()
                    .fill(tint)
                    .frame(width: max(10, CGFloat(safePercent) * 110), height: 8)
            }

            Text("Remaining \(WealthFormat.money(progress.remaining))")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(cardShell(cornerRadius: 18))
    }
}
