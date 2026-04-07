import SwiftUI

struct WealthIBKREndpointCard: View {
    @ObservedObject private var syncStore = WealthSyncStore.shared
    @AppStorage("awc_ibkr_endpoint_locked") private var isLocked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            hostField
            portField
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.cyan, secondaryTint: WealthTheme.green))
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("IBKR 08/04/2026")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Broker endpoint. \u{2022}.21 Mac  \u{2022}.10 iPhone")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }
            Spacer()
            lockToggleButton
        }
    }

    private var lockToggleButton: some View {
        Button {
            isLocked.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 10, weight: .black))
                Text(isLocked ? "LOCKED" : "EDITING")
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }
            .foregroundColor(isLocked ? WealthTheme.grey : WealthTheme.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(cardShell(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var hostField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOST")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
            TextField("Broker host", text: $syncStore.brokerHost)
                .awcHostFieldInputBehavior()
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(isLocked ? WealthTheme.grey : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(cardShell(cornerRadius: 18))
                .disabled(isLocked)
        }
    }

    private var portField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PORT")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
            TextField("Broker port", value: $syncStore.brokerPort, format: .number)
                .awcNumberPadInputBehavior()
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(isLocked ? WealthTheme.grey : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(cardShell(cornerRadius: 18))
                .disabled(isLocked)
        }
    }
}
