import SwiftUI

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
