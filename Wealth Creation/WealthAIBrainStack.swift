import SwiftUI

struct WealthAdvancedAIStackPanel: View {
    private let groups = WealthAIStackCatalog.groups
    @ObservedObject private var toggleStore = WealthBrainToggleStore.shared
    @ObservedObject private var providerStore = WealthExternalDataStore.shared

    private var statusCounts: [(title: String, value: String, tint: Color)] {
        let allItems = groups.flatMap(\.items)
        let truth = allItems.map(WealthBrainModuleRegistry.truth(for:))
        let intel = truth.filter { $0.classification == .intelSupport }.count
        let safety = truth.filter {
            $0.classification == .controlRule || $0.classification == .executionSafety
        }.count
        let offline = truth.filter { $0.activityState == .off || $0.activityState == .notInstalled }.count

        return [
            ("Enabled", toggleStore.runtimeCoverageText, WealthTheme.green),
            ("Intel", "\(intel)", WealthTheme.cyan),
            ("Safety", "\(safety)", WealthTheme.orange),
            ("Offline", "\(offline)", WealthTheme.grey)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ADVANCED BRAIN STACK")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Full build-out map for the brain stack: data, models, automation, risk, and compute.")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                Button {
                    toggleStore.enableAllForCurrentMode()
                } label: {
                    solidPill("ENABLE \(toggleStore.runtimeMode.rawValue)", color: WealthTheme.green, darkText: true)
                }
                .buttonStyle(.plain)
                solidPill(toggleStore.runtimeCoverageText, color: WealthTheme.white, darkText: true)
            }

            HStack(spacing: 10) {
                ForEach(statusCounts, id: \.title) { item in
                    compactSummaryCard(title: item.title, value: item.value, tint: item.tint)
                }
            }

            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.title)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text(group.subtitle)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(WealthTheme.grey)
                        }
                        Spacer()
                        solidPill("\(group.items.count) ITEMS", color: group.tint, darkText: true)
                    }

                    ForEach(group.items) { item in
                        let truth = WealthBrainModuleRegistry.truth(for: item)
                        let enabled = WealthBrainModuleRegistry.isEnabled(title: item.title)
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(enabled ? WealthTheme.green : truth.classification.tint)
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    solidPill(truth.activityState.rawValue, color: truth.activityState.tint, darkText: true)
                                    if truth.allowsToggle {
                                        Button {
                                            WealthBrainModuleRegistry.setEnabled(!enabled, title: item.title)
                                        } label: {
                                            Text(enabled ? "ON" : "OFF")
                                                .font(.system(size: 10, weight: .black, design: .rounded))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(enabled ? WealthTheme.green : WealthTheme.yellow)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        solidPill(truth.classification.rawValue, color: truth.classification.tint, darkText: true)
                                    }
                                }

                                HStack(alignment: .top) {
                                    Text("\(item.note) \(truth.detail)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.78))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 8)
                                    Text(truth.classification.rawValue)
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundColor(truth.classification.tint)
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            cardShell(cornerRadius: 18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke((enabled ? WealthTheme.green : truth.classification.tint).opacity(0.18), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(14)
                .background(glowPanelShell(cornerRadius: 24, tint: group.tint, secondaryTint: WealthTheme.cyan))
            }
        }
    }
}
