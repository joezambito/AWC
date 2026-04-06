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

// MARK: - WealthSheetKeypadButton

struct WealthSheetKeypadButton: View {
    let title: String?
    let systemName: String?
    let action: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.systemName = nil
        self.action = action
    }

    init(systemName: String, action: @escaping () -> Void) {
        self.title = nil
        self.systemName = systemName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                if let title {
                    Text(title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                } else if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WealthPasscodePad

struct WealthPasscodePad: View {
    @Binding var value: String
    let onCommit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            WealthPasscodeDots(count: value.count)

            VStack(spacing: 12) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { number in
                            WealthSheetKeypadButton(title: "\(number)") {
                                append(number)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)

                    WealthSheetKeypadButton(title: "0") {
                        append(0)
                    }

                    WealthSheetKeypadButton(systemName: "delete.left") {
                        if !value.isEmpty {
                            value.removeLast()
                        }
                    }
                }
            }
        }
    }

    private func append(_ digit: Int) {
        guard value.count < 6 else { return }
        value.append(String(digit))
        if value.count == 6 {
            onCommit()
        }
    }
}
