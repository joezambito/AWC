import SwiftUI

struct WealthSystemAIProviderPanel: View {
    @ObservedObject private var providerStore = WealthExternalDataStore.shared
    @AppStorage("awc_provider_options_flow_endpoint") private var optionsFlowEndpoint: String = ""
    @AppStorage("awc_provider_dark_pool_endpoint") private var darkPoolEndpoint: String = ""
    @AppStorage("awc_provider_insider_endpoint") private var insiderEndpoint: String = ""
    @AppStorage("awc_provider_13f_endpoint") private var filing13FEndpoint: String = ""
    @AppStorage("awc_provider_earnings_endpoint") private var earningsEndpoint: String = ""
    @AppStorage("awc_provider_macro_endpoint") private var macroEndpoint: String = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var summaryColumns: [GridItem] {
        let minimum = horizontalSizeClass == .compact ? 120.0 : 140.0
        return [GridItem(.adaptive(minimum: minimum), spacing: 8, alignment: .top)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DATA / TRAINING STACK")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("All provider, calendar, outcome, and retraining layers feeding the score.")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill(providerStore.readinessLabel, color: WealthTheme.green, darkText: true)
            }

            LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 8) {
                compactSummaryCard(title: "Live", value: "\(providerStore.activeProviderCount)", tint: WealthTheme.green)
                compactSummaryCard(title: "Options", value: providerStore.optionsFlowEnabled ? "ON" : "OFF", tint: WealthTheme.cyan)
                compactSummaryCard(title: "Dark Pool", value: providerStore.darkPoolEnabled ? "ON" : "OFF", tint: WealthTheme.purple)
                compactSummaryCard(title: "Outcome", value: providerStore.liveOutcomeLearningEnabled ? "ON" : "OFF", tint: WealthTheme.orange)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PROVIDER ENDPOINTS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                providerEndpointField(title: "Options Flow", endpoint: $optionsFlowEndpoint, kind: .optionsFlow)
                providerEndpointField(title: "Dark Pool", endpoint: $darkPoolEndpoint, kind: .darkPool)
                providerEndpointField(title: "Insider", endpoint: $insiderEndpoint, kind: .insider)
                providerEndpointField(title: "13F", endpoint: $filing13FEndpoint, kind: .filing13F)
                providerEndpointField(title: "Earnings", endpoint: $earningsEndpoint, kind: .earningsCalendar)
                providerEndpointField(title: "Macro", endpoint: $macroEndpoint, kind: .macroCalendar)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("LEARNING / RESEARCH SUPPORT")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                providerSupportToggleRow(title: "Outcome")
                providerSupportToggleRow(title: "Backtest")
                providerSupportToggleRow(title: "Retraining")
                providerSupportToggleRow(title: "Research Mesh")
            }

            VStack(spacing: 8) {
                ForEach(providerStore.providerSources) { source in
                    let truth = WealthBrainModuleRegistry.truth(forTitle: source.name)
                    HStack(spacing: 10) {
                        solidPill(truth.classification.rawValue, color: truth.classification.tint, darkText: true)
                        Text(source.name.uppercased())
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        solidPill(source.status, color: source.tint, darkText: true)
                        Text(source.detail.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    .padding(10)
                    .background(cardShell(cornerRadius: 16))
                }
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 22, tint: WealthTheme.green, secondaryTint: WealthTheme.cyan))
    }

    private func providerEndpointField(
        title: String,
        endpoint: Binding<String>,
        kind: WealthExternalResearchKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                solidPill(WealthBrainModuleRegistry.classification(for: title).rawValue, color: WealthBrainModuleRegistry.classification(for: title).tint, darkText: true)
                providerStatusPill(for: kind)
            }

            Toggle(isOn: providerEnabledBinding(for: kind)) {
                Text("ENABLED")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .tint(WealthTheme.green)

            HStack(spacing: 6) {
                ForEach(WealthExternalProviderMode.allCases) { mode in
                    Button {
                        providerStore.setMode(mode, for: kind)
                    } label: {
                        Text(mode.displayName.uppercased())
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(.black.opacity(0.82))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(providerStore.mode(for: kind) == mode ? WealthTheme.green : WealthTheme.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("http://provider.local", text: endpoint)
                .awcHostFieldInputBehavior()
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(cardShell(cornerRadius: 12))
        }
        .padding(10)
        .background(cardShell(cornerRadius: 16))
    }

    private func providerSupportToggleRow(title: String) -> some View {
        let truth = WealthBrainModuleRegistry.truth(forTitle: title)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    solidPill(truth.classification.rawValue, color: truth.classification.tint, darkText: true)
                }

                Text(truth.detail)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }
            Spacer()
            Toggle("", isOn: WealthBrainModuleRegistry.binding(forTitle: title))
                .labelsHidden()
                .tint(WealthTheme.green)
            solidPill(truth.activityState.rawValue, color: truth.activityState.tint, darkText: true)
        }
        .padding(10)
        .background(cardShell(cornerRadius: 16))
    }

    private func providerStatusPill(for kind: WealthExternalResearchKind) -> some View {
        let status = providerActivationStatus(for: kind)
        let tint: Color

        switch status {
        case "OFF":
            tint = WealthTheme.grey
        case "LIVE_REAL":
            tint = WealthTheme.green
        case "NO_LIVE_CONFIG":
            tint = WealthTheme.orange
        case "WIRED_BUT_FALLBACK":
            tint = WealthTheme.yellow
        case "MISSING_CONFIG":
            tint = WealthTheme.orange
        default:
            tint = WealthTheme.cyan
        }

        return solidPill(status, color: tint, darkText: true)
    }

    private func providerEnabledBinding(for kind: WealthExternalResearchKind) -> Binding<Bool> {
        Binding(
            get: { providerStore.isEnabled(kind) },
            set: { providerStore.setEnabled($0, for: kind) }
        )
    }

    private func providerActivationStatus(for kind: WealthExternalResearchKind) -> String {
        guard providerStore.isEnabled(kind) else { return "OFF" }

        let providerMode = providerStore.mode(for: kind)
        let endpointConfigured = providerStore.endpoint(for: kind) != nil
        let state = providerStore.sourceStatesByKind[kind] ?? .syntheticFallback

        if providerMode == .liveEndpoint && endpointConfigured && (state == .freshOnline || state == .cached) {
            return "LIVE_REAL"
        }

        if providerMode == .liveEndpoint && !endpointConfigured {
            return "NO_LIVE_CONFIG"
        }

        return "WIRED_BUT_FALLBACK"
    }
}
