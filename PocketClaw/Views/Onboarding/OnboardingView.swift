import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var showConnectionForm = false
    @State private var secretTapCount = 0
    @State private var showDemoButton = false

    var body: some View {
        if showConnectionForm {
            onboardingConnectionView
        } else {
            welcomeView
        }
    }

    // MARK: - Welcome Screen

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "terminal")
                .font(.system(size: 72))
                .foregroundStyle(Color.terminalGreen)
                .onTapGesture {
                    secretTapCount += 1
                    if secretTapCount >= 5, !showDemoButton {
                        withAnimation(.spring(duration: 0.4)) {
                            showDemoButton = true
                        }
                    }
                }

            VStack(spacing: 8) {
                Text("PocketClaw")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("OpenClaw in your pocket")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation {
                        showConnectionForm = true
                    }
                } label: {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.terminalGreen)

                if showDemoButton {
                    Button {
                        appVM.startDemoMode()
                    } label: {
                        Text("Try Demo")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Connection Form

    private var onboardingConnectionView: some View {
        OnboardingConnectionForm()
    }
}

// MARK: - Onboarding Connection Form

private struct OnboardingConnectionForm: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var serverURL: String = "wss://"
    @State private var authMode: AuthMode = .token
    @State private var tokenText: String = ""
    @State private var passwordText: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Connect to Your OpenClaw Server")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Form fields
                    VStack(alignment: .leading, spacing: 20) {
                        // Server URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server URL")
                                .font(.headline)

                            TextField("wss://192.168.1.100:18789", text: $serverURL)
                                .textContentType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .font(.system(.body, design: .monospaced))
                                .padding(12)
                                .background(Color(uiColor: .systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Authentication
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Authentication")
                                .font(.headline)

                            Picker("Mode", selection: $authMode) {
                                ForEach(AuthMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            switch authMode {
                            case .token:
                                SecureField("Gateway Token", text: $tokenText)
                                    .textContentType(.password)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(12)
                                    .background(Color(uiColor: .systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            case .password:
                                SecureField("Password", text: $passwordText)
                                    .textContentType(.password)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(12)
                                    .background(Color(uiColor: .systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            // Connect button pinned to bottom
            Button {
                connect()
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                } else {
                    Text("Connect")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.terminalGreen)
            .disabled(!isFormValid || isSaving)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let urlValid = serverURL.trimmingCharacters(in: .whitespaces).count > 6 // more than "wss://"
        let authValid: Bool
        switch authMode {
        case .token:
            authValid = !tokenText.trimmingCharacters(in: .whitespaces).isEmpty
        case .password:
            authValid = !passwordText.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return urlValid && authValid
    }

    // MARK: - Actions

    private func connect() {
        errorMessage = nil
        isSaving = true

        let trimmedURL = serverURL.trimmingCharacters(in: .whitespaces)

        guard trimmedURL.hasPrefix("ws://") || trimmedURL.hasPrefix("wss://") else {
            errorMessage = "URL must start with ws:// or wss://"
            isSaving = false
            return
        }

        // Save credentials
        do {
            switch authMode {
            case .token:
                try KeychainService.shared.saveToken(tokenText.trimmingCharacters(in: .whitespaces))
                try? KeychainService.shared.deletePassword()
            case .password:
                try KeychainService.shared.savePassword(passwordText.trimmingCharacters(in: .whitespaces))
                try? KeychainService.shared.deleteToken()
            }
        } catch {
            errorMessage = "Failed to save credentials: \(error.localizedDescription)"
            isSaving = false
            return
        }

        // Save settings, complete onboarding, and connect
        appVM.saveConnectionSettings(url: trimmedURL, authMode: authMode)
        appVM.completeOnboarding()

        Task {
            await appVM.connect()
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView()
        .environment(AppViewModel())
        .preferredColorScheme(.dark)
}
