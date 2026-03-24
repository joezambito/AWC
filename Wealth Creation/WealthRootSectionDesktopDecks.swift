import SwiftUI

struct WealthDesktopGraphDeckView: View {
    let portfolioTint: Color
    let portfolioPoints: [Double]
    let aiFlowPoints: [Double]
    let reservePoints: [Double]

    var body: some View {
        VStack(spacing: 12) {
            sectionShell(title: "MAC OVERVIEW", subtitle: "Desktop-only visual rails", trailing: "LIVE")
            WealthGraphCard(title: "PORTFOLIO WAVE", subtitle: "Net position after fees", tint: portfolioTint, points: portfolioPoints)
            WealthGraphCard(title: "BRAIN FLOW", subtitle: "Current ranked share strength", tint: WealthTheme.cyan, points: aiFlowPoints)
            WealthGraphCard(title: "CAPITAL BUFFER", subtitle: "Broker cash, floor, and free trade room", tint: WealthTheme.purple, points: reservePoints)
        }
    }
}

struct WealthDesktopHistoryRailView: View {
    let moments: [NotificationMomentViewModel]

    var body: some View {
        VStack(spacing: 12) {
            sectionShell(title: "EVENT HISTORY", subtitle: "Desktop-only recent activity rail", trailing: "\(moments.count)")

            if moments.isEmpty {
                compactSummaryCard(title: "Recent", value: "CLEAR", tint: WealthTheme.green)
            } else {
                VStack(spacing: 8) {
                    ForEach(moments) { moment in
                        WealthDesktopMomentCard(moment: moment)
                    }
                }
            }
        }
    }
}

struct WealthDesktopCommandDeckView: View {
    let confirmedCount: Int
    let pendingCount: Int
    let completedCount: Int
    let notificationsReady: Bool

    var body: some View {
        VStack(spacing: 12) {
            sectionShell(title: "COMMAND DECK", subtitle: "Mac-only holdings, alerts and timezone pulse", trailing: "AEST")

            HStack(spacing: 10) {
                compactSummaryCard(title: "Confirmed", value: "\(confirmedCount)", tint: WealthTheme.green)
                compactSummaryCard(title: "Pending", value: "\(pendingCount)", tint: pendingCount > 0 ? WealthTheme.orange : WealthTheme.green)
                compactSummaryCard(title: "Completed", value: "\(completedCount)", tint: completedCount > 0 ? WealthTheme.cyan : WealthTheme.grey)
            }

            HStack(spacing: 10) {
                miniReferenceCard(title: "Timezone", value: "BRISBANE", accent: WealthTheme.cyan, tag: "NO DST")
                miniReferenceCard(title: "Watch Alerts", value: notificationsReady ? "READY" : "OFF", accent: notificationsReady ? WealthTheme.green : WealthTheme.grey, tag: notificationsReady ? "MIRROR" : "CHECK")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("DESKTOP NOTES")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))

                WealthDesktopNoteRow(title: "Holdings stay clean", detail: "Only confirmed positions remain on the dashboard. Submitted and partial orders stay in Activity until IBKR confirms them.", tint: WealthTheme.green)
                WealthDesktopNoteRow(title: "Money stays broker-aware", detail: "The brain reads IBKR cash, respects the floor reserve, and keeps pending order capital out of the next buy.", tint: WealthTheme.cyan)
                WealthDesktopNoteRow(title: "Desktop stays colorful", detail: "The Mac view keeps richer graphs, status rails, and broker decks while the phone stays lighter.", tint: WealthTheme.purple)
            }
            .padding(12)
            .background(cardShell(cornerRadius: 20))
        }
    }
}
