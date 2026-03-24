import SwiftUI

struct NotificationMomentViewModel: Identifiable {
    let id: String
    let title: String
    let detail: String
    let timestampText: String
    let tint: Color
}

struct WealthDesktopMomentCard: View {
    let moment: NotificationMomentViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(moment.tint)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(moment.title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(moment.tint == WealthTheme.white ? .white : moment.tint)
                    Spacer()
                    Text(moment.timestampText)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Text(moment.detail)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.76))
            }
        }
        .padding(12)
        .background(cardShell(cornerRadius: 18))
    }
}

struct WealthDesktopNoteRow: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(tint)
                Text(detail)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.76))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.15), lineWidth: 0.8)
                )
        )
    }
}
