import SwiftUI

// MARK: - WealthRootView

struct WealthRootView: View {
    var body: some View {
        EmptyView()
    }
}

// MARK: - WealthPasscodeDots

struct WealthPasscodeDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < count ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
    }
}

// MARK: - WealthPasscodeChangeSheet

struct WealthPasscodeChangeSheet: View {
    @EnvironmentObject private var auth: WealthAuthStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EmptyView()
    }
}

// MARK: - WealthPasscodeResetSheet

struct WealthPasscodeResetSheet: View {
    @EnvironmentObject private var auth: WealthAuthStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EmptyView()
    }
}
