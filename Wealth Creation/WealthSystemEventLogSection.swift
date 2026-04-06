import SwiftUI

struct WealthSystemEventLogSection: View {
    @ObservedObject private var logStore = WealthEventLogStore.shared
    @ObservedObject private var engine = WealthEngineStore.shared
    @ObservedObject private var syncStore = WealthSyncStore.shared

    var body: some View {
#if targetEnvironment(macCatalyst)
        desktopEventLog
#else
        phoneScanLog
#endif
    }

    private var desktopEventLog: some View {
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

    private var phoneScanLog: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SCAN LOG")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("AI passes first, with IBKR checkpoints and broker status underneath.")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    Spacer()
                    solidPill(logStore.retentionLabel, color: WealthTheme.orange, darkText: true)
                }

                HStack(spacing: 10) {
                    compactSummaryCard(title: "AI Scan", value: aiSummaryValue, tint: WealthTheme.cyan)
                    compactSummaryCard(title: "IBKR", value: ibkrSummaryValue, tint: ibkrSummaryTint)
                    compactSummaryCard(title: "Latest", value: WealthFormat.dayClock(phoneScanEntries.first?.timestamp), tint: WealthTheme.green)
                }
            }
            .padding(14)
            .background(cardShell(cornerRadius: 24))

            if let startupRow {
                scanRow(
                    title: startupRow.title,
                    detail: startupRow.detail,
                    category: startupRow.category,
                    tint: startupRow.tint,
                    timestamp: startupRow.timestamp
                )
            }

            if phoneScanEntries.isEmpty {
                VStack(spacing: 8) {
                    Text("NO SCANS YET")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("This log fills with AI passes, IBKR checkpoints, and broker scan outcomes.")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(cardShell(cornerRadius: 24))
            } else {
                VStack(spacing: 8) {
                    ForEach(phoneScanEntries) { entry in
                        scanRow(
                            title: scanDisplayTitle(for: entry),
                            detail: entry.detail,
                            category: scanDisplayCategory(for: entry),
                            tint: entry.tint,
                            timestamp: entry.timestamp
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scanRow(
        title: String,
        detail: String,
        category: String,
        tint: Color,
        timestamp: Date
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(tint)
                    Spacer()
                    Text(WealthFormat.dayClock(timestamp))
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                }

                Text(detail)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.84))

                Text(category.uppercased())
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.46))
            }
        }
        .padding(12)
        .background(
            cardShell(cornerRadius: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 0.9)
                )
        )
    }

    private var phoneScanEntries: [WealthEventLogEntry] {
        Array(
            logStore.entries
                .filter(isPhoneScanEntry)
                .prefix(24)
        )
    }

    private func isPhoneScanEntry(_ entry: WealthEventLogEntry) -> Bool {
        if entry.category == "scan" || entry.category == "broker" {
            return true
        }
        if entry.category == "refresh" {
            return entry.detail.localizedCaseInsensitiveContains("scan")
        }
        return false
    }

    private var aiSummaryValue: String {
        let checkpointCount = WealthEngineStore.lockedCheckpointCount
        if engine.startupSequenceInFlight {
            let current = min(checkpointCount, max(1, engine.lockedCheckpointProgress))
            return "\(current)/\(checkpointCount)"
        }
        if let latestAIScan = phoneScanEntries.first(where: isAIEntry) {
            return WealthFormat.dayClock(latestAIScan.timestamp)
        }
        return "\(engine.lockedCheckpointProgress)/\(checkpointCount)"
    }

    private var ibkrSummaryValue: String {
        if syncStore.syncStatus == "CONNECTING" {
            return "LIVE"
        }
        if let latestIBKR = phoneScanEntries.first(where: isIBKREntry) {
            return WealthFormat.dayClock(latestIBKR.timestamp)
        }
        return "WAITING"
    }

    private var ibkrSummaryTint: Color {
        if syncStore.syncStatus == "TWS FAILED" {
            return WealthTheme.red
        }
        if syncStore.syncStatus == "CONNECTING" || syncStore.syncStatus.contains("TWS") {
            return WealthTheme.cyan
        }
        return WealthTheme.blue
    }

    private var startupRow: WealthEventLogEntry? {
        guard engine.startupSequenceInFlight else { return nil }

        let detail: String
        let tintName: String
        switch engine.startupSequencePhase {
        case .idle:
            return nil
        case .waitingToScan:
            detail = "Phone is open and holding 2 seconds before the startup AI scan begins."
            tintName = "orange"
        case .aiScanRunning:
            detail = "Startup AI scan is running now at checkpoint \(max(1, engine.lockedCheckpointProgress))/\(WealthEngineStore.lockedCheckpointCount)."
            tintName = "cyan"
        case .postScanHold:
            detail = "Startup AI scan finished. The phone is holding before universe refresh starts."
            tintName = "green"
        case .universeRefreshRunning:
            detail = "Universe refresh is running after the startup AI scan finished."
            tintName = "blue"
        case .marketWarmupRunning:
            detail = "Market warmup is running after universe refresh finished."
            tintName = "purple"
        }

        return WealthEventLogEntry(
            id: "startup-live-row",
            title: "Startup \(startupPhaseTitle)",
            detail: detail,
            category: "live",
            tintName: tintName,
            timestamp: engine.startupSequenceUpdatedAt
        )
    }

    private var startupPhaseTitle: String {
        switch engine.startupSequencePhase {
        case .idle:
            return "Idle"
        case .waitingToScan:
            return "App Open"
        case .aiScanRunning:
            return "AI Scan"
        case .postScanHold:
            return "Hold"
        case .universeRefreshRunning:
            return "Universe"
        case .marketWarmupRunning:
            return "Market"
        }
    }

    private func scanDisplayTitle(for entry: WealthEventLogEntry) -> String {
        if entry.title == "Soft Scan" {
            return "AI Soft Scan"
        }
        if entry.title == "Hard Scan" {
            return "AI Deep Scan"
        }
        return entry.title
    }

    private func scanDisplayCategory(for entry: WealthEventLogEntry) -> String {
        if isIBKREntry(entry) {
            return "IBKR"
        }
        if isAIEntry(entry) {
            return "AI"
        }
        return entry.category
    }

    private func isAIEntry(_ entry: WealthEventLogEntry) -> Bool {
        entry.category == "scan" || entry.title.localizedCaseInsensitiveContains("refresh")
    }

    private func isIBKREntry(_ entry: WealthEventLogEntry) -> Bool {
        entry.category == "broker" || entry.title.localizedCaseInsensitiveContains("IBKR") || entry.title.localizedCaseInsensitiveContains("TWS")
    }
}
