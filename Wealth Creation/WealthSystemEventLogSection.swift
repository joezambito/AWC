import SwiftUI

struct WealthSystemEventLogSection: View {
    @ObservedObject private var logStore = WealthEventLogStore.shared

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("EVENT LOG")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(logStore.retentionSubtitle)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    Spacer()
                    solidPill(logStore.retentionLabel, color: WealthTheme.orange, darkText: true)
                }

                HStack(spacing: 10) {
                    compactSummaryCard(title: "Entries", value: "\(logStore.entries.count)", tint: WealthTheme.cyan)
                    compactSummaryCard(title: "Latest", value: WealthFormat.dayClock(logStore.entries.first?.timestamp), tint: WealthTheme.green)
                }
            }
            .padding(14)
            .background(cardShell(cornerRadius: 24))

            if logStore.entries.isEmpty {
                VStack(spacing: 8) {
                    Text("NO EVENTS YET")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("The log fills as the engine scans, refreshes, buys, sells, and syncs.")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(cardShell(cornerRadius: 24))
            } else {
                VStack(spacing: 8) {
                    ForEach(logStore.entries) { entry in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(entry.tint)
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.title.uppercased())
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(entry.tint)
                                    Spacer()
                                    Text(WealthFormat.dayClock(entry.timestamp))
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundColor(.white.opacity(0.58))
                                }

                                Text(entry.detail)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.84))

                                Text(entry.category.uppercased())
                                    .font(.system(size: 8, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.46))
                            }
                        }
                        .padding(12)
                        .background(
                            cardShell(cornerRadius: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(entry.tint.opacity(0.18), lineWidth: 0.9)
                                )
                        )
                    }
                }
            }
        }
    }
}
