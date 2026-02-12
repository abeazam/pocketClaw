import SwiftUI

// MARK: - SSH Connection Form

struct SSHConnectionForm: View {
    @Bindable var viewModel: TerminalViewModel

    @State private var isConnecting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.terminalGreen)

                    Text("SSH Terminal")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Connect to a remote machine")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Form fields
                VStack(alignment: .leading, spacing: 20) {
                    // Host
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Host")
                            .font(.headline)

                        TextField("hostname or IP address", text: $viewModel.host)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Port
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Port")
                            .font(.headline)

                        TextField("22", text: $viewModel.port)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Username
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)

                        TextField("username", text: $viewModel.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)

                        SecureField("password", text: $viewModel.password)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 24)

                // Connect button
                Button {
                    isConnecting = true
                    Task {
                        await viewModel.connect()
                        isConnecting = false
                    }
                } label: {
                    if isConnecting {
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
                .disabled(!isFormValid || isConnecting)
                .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let hostValid = !viewModel.host.trimmingCharacters(in: .whitespaces).isEmpty
        let userValid = !viewModel.username.trimmingCharacters(in: .whitespaces).isEmpty
        let passValid = !viewModel.password.trimmingCharacters(in: .whitespaces).isEmpty
        let portValid: Bool
        if let p = Int(viewModel.port) {
            portValid = p > 0 && p <= 65535
        } else {
            portValid = false
        }
        return hostValid && userValid && passValid && portValid
    }
}

// MARK: - Preview

#Preview {
    SSHConnectionForm(viewModel: TerminalViewModel())
        .preferredColorScheme(.dark)
}
