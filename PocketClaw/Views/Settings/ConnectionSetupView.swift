import SwiftUI

// MARK: - Auth Mode

enum AuthMode: String, CaseIterable, Identifiable {
    case token
    case password

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .token: "Token"
        case .password: "Password"
        }
    }
}

// MARK: - Connection Setup View

struct ConnectionSetupView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL: String = ""
    @State private var authMode: AuthMode = .token
    @State private var tokenText: String = ""
    @State private var passwordText: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        Form {
            serverSection
            authSection
            actionSection
        }
        .navigationTitle("Connection")
        .onAppear {
            loadExistingSettings()
        }
    }

    // MARK: - Sections

    private var serverSection: some View {
        Section("Server") {
            TextField("wss://192.168.1.100:18789", text: $serverURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .font(.system(.body, design: .monospaced))
        }
    }

    private var authSection: some View {
        Section("Authentication") {
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
            case .password:
                SecureField("Password", text: $passwordText)
                    .textContentType(.password)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                saveAndConnect()
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save & Connect")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            }
            .disabled(!isFormValid || isSaving)
            .tint(.terminalGreen)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let urlValid = !serverURL.trimmingCharacters(in: .whitespaces).isEmpty
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

    private func loadExistingSettings() {
        serverURL = appVM.serverURL
        if let mode = AuthMode(rawValue: appVM.authMode) {
            authMode = mode
        }
        // Load existing credentials
        switch authMode {
        case .token:
            tokenText = KeychainService.shared.loadToken() ?? ""
        case .password:
            passwordText = KeychainService.shared.loadPassword() ?? ""
        }
    }

    private func saveAndConnect() {
        errorMessage = nil
        isSaving = true

        let trimmedURL = serverURL.trimmingCharacters(in: .whitespaces)

        // Validate URL format
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

        // Save connection settings and connect
        appVM.saveConnectionSettings(url: trimmedURL, authMode: authMode)

        Task {
            await appVM.connect()
        }

        isSaving = false
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ConnectionSetupView()
            .environment(AppViewModel.preview)
    }
    .preferredColorScheme(.dark)
}
