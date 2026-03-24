import SwiftUI

struct WealthAdvancedAIStackPanel: View {
    private let groups = WealthAIStackCatalog.groups
    @ObservedObject private var toggleStore = WealthBrainToggleStore.shared

    private var statusCounts: [(title: String, value: String, tint: Color)] {
        let allItems = groups.flatMap(\.items)
        let planned = allItems.filter { $0.status == .planned }.count
        let external = allItems.filter { $0.status == .external }.count

        return [
            ("Enabled", "\(toggleStore.activeRuntimeCount)", WealthTheme.green),
            ("Available", "\(toggleStore.totalRunnableCount)", WealthTheme.cyan),
            ("Planned", "\(planned)", WealthTheme.orange),
            ("External", "\(external)", WealthTheme.purple)
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
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(toggleStore.isEnabled(item) ? WealthTheme.green : WealthTheme.orange)
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        toggleStore.toggle(item)
                                    } label: {
                                        Text(toggleStore.isEnabled(item) ? "ON" : "OFF")
                                            .font(.system(size: 10, weight: .black, design: .rounded))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(toggleStore.isEnabled(item) ? WealthTheme.green : WealthTheme.orange)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(alignment: .top) {
                                    Text(item.note)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.78))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 8)
                                    Text(item.status == .external ? item.status.rawValue : "\(item.status.rawValue) · \(toggleStore.runtimeMode.rawValue)")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundColor(item.status.color)
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            cardShell(cornerRadius: 18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke((toggleStore.isEnabled(item) ? WealthTheme.green : WealthTheme.orange).opacity(0.18), lineWidth: 1)
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
