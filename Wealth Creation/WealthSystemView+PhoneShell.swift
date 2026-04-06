import SwiftUI

extension SystemView {
    var phoneTabs: [SystemTab] {
        SystemTab.allCases
    }
    var phoneSystemShell: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                phoneHeaderCard
                phoneSystemTabs
                activeSystemView
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .id("system-phone-\(tab.rawValue)")
    }

    var phoneHeaderCard: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SYSTEM")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("Parameters + broker controls")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardShell(cornerRadius: 22))
    }

    var phoneSystemTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(phoneTabs) { item in
                    Button {
                        tab = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(tab == item ? .black : .white.opacity(0.84))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(phoneTabBackground(for: item))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(phoneTabsShell)
    }

    private var phoneTabsShell: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
    }

    private func phoneTabBackground(for item: SystemTab) -> some View {
        let active = tab == item
        let tint = active ? phoneTabTint(for: item) : Color.white.opacity(0.04)

        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(tint)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke((active ? tint : Color.white).opacity(0.10), lineWidth: 0.8)
            )
    }
}
