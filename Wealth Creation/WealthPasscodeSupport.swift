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

// MARK: - WealthPasscodeChangeSheet

struct WealthPasscodeChangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: WealthAuthStore

    @State private var step: ChangeStep = .current
    @State private var current = ""
    @State private var candidate = ""
    @State private var confirmation = ""
    @State private var message = ""

    private enum ChangeStep: String {
        case current = "Enter current passcode"
        case new = "Enter new passcode"
        case confirm = "Confirm new passcode"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(step.rawValue)
                    .font(.system(size: 18, weight: .black, design: .rounded))

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                WealthPasscodePad(value: activeBinding, onCommit: advance)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Change Passcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var activeBinding: Binding<String> {
        switch step {
        case .current:
            $current
        case .new:
            $candidate
        case .confirm:
            $confirmation
        }
    }

    private func advance() {
        switch step {
        case .current:
            guard auth.verify(passcode: current) else {
                message = "Current passcode is incorrect."
                current = ""
                return
            }
            message = ""
            step = .new

        case .new:
            guard candidate.count == 6 else {
                candidate = ""
                return
            }
            message = ""
            step = .confirm

        case .confirm:
            guard confirmation == candidate else {
                message = "New passcode does not match."
                confirmation = ""
                return
            }
            _ = auth.changePasscode(current: current, new: candidate)
            dismiss()
        }
    }
}

// MARK: - WealthPasscodeResetSheet

struct WealthPasscodeResetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: WealthAuthStore

    @State private var verified = false
    @State private var step: ResetStep = .new
    @State private var candidate = ""
    @State private var confirmation = ""
    @State private var message = ""
    @State private var isChecking = false

    private enum ResetStep: String {
        case new = "Enter new passcode"
        case confirm = "Confirm new passcode"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if verified {
                    Text(step.rawValue)
                        .font(.system(size: 18, weight: .black, design: .rounded))

                    if !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    WealthPasscodePad(value: activeBinding, onCommit: advance)
                } else {
                    Text("Verify your identity to reset the passcode.")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Button(isChecking ? "Checking..." : "Verify and Continue") {
                        verify()
                    }
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WealthTheme.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(isChecking)

                    if !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Reset Passcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var activeBinding: Binding<String> {
        step == .new ? $candidate : $confirmation
    }

    private func verify() {
        isChecking = true
        message = ""
        Task {
            let success = await auth.authenticateForReset()
            await MainActor.run {
                isChecking = false
                verified = success
                if !success {
                    message = "Verification failed."
                }
            }
        }
    }

    private func advance() {
        switch step {
        case .new:
            guard candidate.count == 6 else {
                candidate = ""
                return
            }
            message = ""
            step = .confirm

        case .confirm:
            guard confirmation == candidate else {
                message = "New passcode does not match."
                confirmation = ""
                return
            }
            auth.resetPasscode(candidate)
            dismiss()
        }
    }
}
