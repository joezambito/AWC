import SwiftUI

@MainActor
struct WealthLiveMarketDebugPanel: View {
    @ObservedObject private var liveStore = WealthLiveMarketDataStore.shared
    @ObservedObject private var brokerStore = WealthBrokerStore.shared
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            displayModeRow
            summaryGrid
            if brokerStore.brokerDisplayMode == .debug && !compact && !liveStore.visibleDiagnostics.isEmpty {
                diagnosticsList
            }
            if brokerStore.brokerDisplayMode == .debug && !compact && !liveStore.visibleErrors.isEmpty {
                errorList
            }
            if compact {
                compactFooter
            }
        }
        .padding(14)
        .background(cardShell(cornerRadius: compact ? 20 : 24))
        .onAppear {
            if !compact {
                liveStore.setBrokerUIScreenVisible(true)
            }
        }
        .onDisappear {
            liveStore.setBrokerUIScreenVisible(false)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LIVE MARKET DEBUG")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(liveStore.endpointLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }
            Spacer()
            solidPill(liveStore.connectionStatus, color: liveStore.twsConnected ? WealthTheme.green : WealthTheme.orange, darkText: true)
        }
    }

    private var summaryGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                debugCell("Connected", liveStore.twsConnected ? "TRUE" : "FALSE", tint: liveStore.twsConnected ? WealthTheme.green : WealthTheme.orange)
                debugCell("Data Type", liveStore.marketDataType == 3 ? "DELAYED" : "LIVE", tint: liveStore.marketDataType == 3 ? WealthTheme.orange : WealthTheme.cyan)
            }
            HStack(spacing: 8) {
                debugCell("Last Tick", liveStore.lastTickReceivedAt.map(WealthFormat.age) ?? "No ticks", tint: WealthTheme.gold)
                debugCell("Client", "#\(liveStore.clientID)", tint: WealthTheme.purple)
            }
            HStack(spacing: 8) {
                debugCell("Host", "\(liveStore.connectionHost):\(liveStore.connectionPort)", tint: WealthTheme.cyan)
                debugCell("Message", liveStore.lastConnectionMessage.isEmpty ? "--" : liveStore.lastConnectionMessage, tint: WealthTheme.white)
            }
        }
    }

    private var displayModeRow: some View {
        HStack(spacing: 10) {
            Text("BROKER DISPLAY")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.62))

            Picker("Broker Display Mode", selection: $brokerStore.brokerDisplayMode) {
                ForEach(WealthBrokerStore.BrokerDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: brokerStore.brokerDisplayMode) { _, _ in
                brokerStore.persistRouting()
            }
        }
    }

    private var diagnosticsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYMBOLS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.62))

            ForEach(liveStore.visibleDiagnostics) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.symbolLabel)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("REQ \(item.requestID ?? 0)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(WealthTheme.cyan)
                    }

                    Text(contractText(for: item))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)

                    HStack(spacing: 8) {
                        debugMiniPill(item.reqMktDataSent ? "REQ YES" : "REQ NO", tint: item.reqMktDataSent ? WealthTheme.green : WealthTheme.orange)
                        debugMiniPill("PRICE \(item.tickPriceCount)", tint: WealthTheme.cyan)
                        debugMiniPill("SIZE \(item.tickSizeCount)", tint: WealthTheme.gold)
                        if let lastErrorCode = item.lastErrorCode {
                            debugMiniPill("ERR \(lastErrorCode)", tint: WealthTheme.red)
                        }
                    }
                }
                .padding(12)
                .background(cardShell(cornerRadius: 16))
            }
        }
    }

    private var errorList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("IB ERRORS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.62))

            ForEach(liveStore.visibleErrors) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(WealthTheme.red)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("CODE \(item.code ?? 0)  REQ \(item.requestID ?? 0)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(item.message)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.82))
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .background(cardShell(cornerRadius: 16))
            }
        }
    }

    private var compactFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                brokerStore.brokerDisplayMode == .off
                    ? "BROKER DISPLAY IS OFF. SYMBOLS STAY IN THE BACKGROUND STORE ONLY."
                    : "PHONE DEBUG IS SUMMARY-ONLY TO REDUCE LIVE UI CHURN."
            )
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.56))

            HStack(spacing: 8) {
                debugMiniPill("RAW \(liveStore.rawQuoteCount)", tint: WealthTheme.cyan)
                debugMiniPill("UI \(liveStore.visibleDiagnostics.count)", tint: WealthTheme.green)
                debugMiniPill("RX \(liveStore.receivedQuoteUpdatesInCycle)", tint: WealthTheme.gold)
            }

            Text(liveStore.lastBrokerPerfMessage)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
                .lineLimit(2)
        }
    }

    private func debugCell(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(cardShell(cornerRadius: 14))
    }

    private func debugMiniPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private func contractText(for item: WealthLiveMarketDataStore.SymbolDiagnostics) -> String {
        guard let contract = item.contract else { return "No contract" }
        let primaryExchange = contract.primaryExchange.isEmpty ? "--" : contract.primaryExchange
        return "\(contract.symbol) \(contract.secType) \(contract.exchange) \(primaryExchange) \(contract.currency)"
    }
}
