import SwiftUI

// MARK: - WealthUnlockedRootHost

struct WealthUnlockedRootHost: View {
    var body: some View {
        WealthRootView()
            .id("awc-root-host")
    }
}

// MARK: - WealthLockView

struct WealthLockView: View {
    @EnvironmentObject private var auth: WealthAuthStore
    @AppStorage("awc_root_is_unlocked") private var isUnlocked = false

    @State var passcode = ""
    @State var message = ""
    @State var showChangePasscode = false
    @State var showResetPasscode = false
    @FocusState private var passcodeFocused: Bool

    var body: some View {
        ZStack {
            lockBackground

            VStack {
                Spacer(minLength: 28)

                VStack(spacing: 18) {
                    badge
                    logo
                    titleBlock
                    faceIDButton
                    passcodeDisplay
                    passcodeField
                    passcodeUnlockButton
                    messageView
                    helperText
                    actions
                }
                .padding(20)
                .background(cardBackground)
                .padding(.horizontal, 22)

                Spacer(minLength: 24)
            }
        }
        .sheet(isPresented: $showChangePasscode) {
            WealthPasscodeChangeSheet()
                .environmentObject(auth)
        }
        .sheet(isPresented: $showResetPasscode) {
            WealthPasscodeResetSheet()
                .environmentObject(auth)
        }
    }

    private var passcodeDisplay: some View {
        WealthPasscodeDots(count: passcode.count)
            .padding(.top, 2)
    }

    private var passcodeField: some View {
        SecureField("Enter 6-digit passcode", text: $passcode)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($passcodeFocused)
            .font(.system(size: 1))
            .foregroundColor(.clear)
            .accentColor(.clear)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.clear)
            .onChange(of: passcode) { _, newValue in
                let filtered = String(newValue.filter(\.isNumber).prefix(6))
                if filtered != passcode {
                    passcode = filtered
                    return
                }

                message = ""
                if filtered.count == 6 {
                    validatePasscode()
                }
            }
    }

    private var faceIDButton: some View {
        Button {
            unlockWithBiometrics()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "faceid")
                    .font(.system(size: 24, weight: .bold))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Unlock with Face ID")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                    Text("Use iPhone security")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.black.opacity(0.72))
                }

                Spacer()
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [WealthTheme.cyan, WealthTheme.blue.opacity(0.82)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var passcodeUnlockButton: some View {
        Button(passcode.isEmpty ? "Use Passcode" : "Unlock with Passcode") {
            if passcode.count == 6 {
                validatePasscode()
            } else {
                passcodeFocused = true
            }
        }
        .font(.system(size: 15, weight: .black, design: .rounded))
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(WealthTheme.orange)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .buttonStyle(.plain)
    }

    private func validatePasscode() {
        guard passcode.count == 6 else { return }
        passcodeFocused = false
        if auth.unlockWithPasscode(passcode) {
            isUnlocked = true
            passcode = ""
            message = ""
        } else {
            message = "Wrong passcode"
            passcode = ""
            DispatchQueue.main.async {
                passcodeFocused = true
            }
        }
    }

    private func unlockWithBiometrics() {
        message = ""
        Task {
            let success = await auth.unlockWithBiometrics()
            await MainActor.run {
                if success {
                    isUnlocked = true
                    passcode = ""
                } else {
                    message = "Face ID unavailable. Use passcode below."
                    passcodeFocused = true
                }
            }
        }
    }
}

// MARK: - WealthLockView subviews

private extension WealthLockView {

    var lockBackground: some View {
        LinearGradient(
            colors: [Color.black, Color(white: 0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(white: 0.12))
    }

    var badge: some View {
        Image(systemName: "lock.shield.fill")
            .font(.system(size: 42, weight: .bold))
            .foregroundColor(WealthTheme.cyan)
    }

    var logo: some View {
        Text("AWC")
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundColor(.white)
    }

    var titleBlock: some View {
        VStack(spacing: 4) {
            Text("Unlock to Continue")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text("Authenticate to access your portfolio")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    var messageView: some View {
        Group {
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    var helperText: some View {
        Text("Enter your 6-digit passcode or use Face ID above")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.40))
            .multilineTextAlignment(.center)
    }

    var actions: some View {
        HStack(spacing: 16) {
            Button("Change Passcode") {
                showChangePasscode = true
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.55))

            Spacer()

            Button("Reset Access") {
                showResetPasscode = true
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.55))
        }
    }
}

