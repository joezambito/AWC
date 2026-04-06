import SwiftUI
import Combine
import UserNotifications

@MainActor
final class WealthNotificationStore: ObservableObject {
    struct NotificationMoment: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
        let timestamp: Date
    }

    static let shared = WealthNotificationStore()

    @Published private(set) var isAuthorized = false
    @Published private(set) var lastMessage = "Idle"
    @Published private(set) var recentMoments: [NotificationMoment] = []

    private var deliveredAt: [String: Date] = [:]
    private let debounceWindow: TimeInterval = 20 * 60

    private init() {}

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            isAuthorized = granted
            lastMessage = granted ? "Notifications enabled" : "Notifications blocked"
        } catch {
            lastMessage = "Notification auth error"
        }
    }

    func processEngineMoments(
        opportunities: [Opportunity],
        holdings: [Holding],
        buyingPower: Double,
        protection: WealthProtectionSettingsStore
    ) {
        guard isAuthorized else { return }

        if let top = opportunities.first(where: { $0.orderState == .ready && $0.cardHoldingBucket == .green && $0.sessionState.canTradeNow }) {
            if protection.capitalAlertEnabled && top.trueCost > buyingPower {
                postMoment(
                    id: "capital-\(top.symbol)",
                    title: "Capital Alert",
                    body: "\(top.symbol) is ready but needs \(WealthFormat.money(top.trueCost)) while only \(WealthFormat.money(buyingPower)) is free."
                )
            } else if protection.speedAlertEnabled && top.priceChangePercent >= 2 {
                postMoment(
                    id: "speed-\(top.symbol)",
                    title: "Speed Alert",
                    body: "\(top.symbol) is moving fast with \(top.confidence)% confidence and is tradable now."
                )
            }
        }

        if let queued = opportunities.first(where: { $0.orderState == .ready && $0.cardHoldingBucket == .green && !$0.sessionState.canTradeNow }) {
            postMoment(
                id: "queue-\(queued.symbol)",
                title: "Queued For Open",
                body: "\(queued.symbol) was found outside broker hours and will be rechecked at the next open."
            )
        }

        if let pending = opportunities.first(where: { $0.orderState == .submitted || $0.orderState == .pending || $0.orderState == .partial }) {
            postMoment(
                id: "order-\(pending.symbol)-\(pending.orderState.rawValue)",
                title: "Order Update",
                body: "\(pending.symbol) is \(pending.orderState.rawValue.lowercased()) at \(WealthFormat.money(pending.submittedPrice))."
            )
        }

        if let pendingSell = holdings.first(where: { $0.orderIntent == .sellPending }) {
            postMoment(
                id: "sell-\(pendingSell.symbol)",
                title: "Sell Waiting",
                body: "\(pendingSell.symbol) is waiting for broker confirmation. Capital updates after the net sale completes."
            )
        }

        if let completed = opportunities.first(where: { $0.orderState == .filled && Date().timeIntervalSince($0.analysisTimestamp) < 4 * 60 * 60 }) {
            postMoment(
                id: "filled-\(completed.symbol)",
                title: "Order Filled",
                body: "\(completed.symbol) completed at \(WealthFormat.money(completed.submittedPrice)) and rolled into the account."
            )
        }
    }

    private func postMoment(id: String, title: String, body: String) {
        let now = Date()
        if let last = deliveredAt[id], now.timeIntervalSince(last) < debounceWindow {
            return
        }

        deliveredAt[id] = now
        lastMessage = title
        recentMoments.insert(NotificationMoment(id: id, title: title, detail: body, timestamp: now), at: 0)
        recentMoments = Array(recentMoments.prefix(8))

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: recentMoments.count)

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }
}
