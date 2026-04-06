import SwiftUI

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
