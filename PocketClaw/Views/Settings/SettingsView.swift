import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section("Connection") {
            HStack {
                Text("Status")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(appVM.isDemoMode ? "Demo Mode" : appVM.connectionState.displayText)
                        .foregroundStyle(.secondary)
                }
            }

            if appVM.isDemoMode {
                HStack {
                    Text("Server")
                    Spacer()
                    Text("Demo Mode")
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }

                Button("Exit Demo", role: .destructive) {
                    appVM.exitDemoMode()
                }
            } else if !appVM.serverURL.isEmpty {
                NavigationLink {
                    ConnectionSetupView()
                } label: {
                    HStack {
                        Text("Server")
                        Spacer()
                        Text(appVM.serverURL)
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                HStack {
                    Text("Authentication")
                    Spacer()
                    Text(appVM.authMode.capitalized)
                        .foregroundStyle(.secondary)
                }

                Button("Disconnect", role: .destructive) {
                    appVM.disconnect()
                }
            } else {
                NavigationLink("Set Up Connection") {
                    ConnectionSetupView()
                }
            }
        }
    }

    // MARK: - Appearance Section

    @ViewBuilder
    private var appearanceSection: some View {
        @Bindable var vm = appVM
        Section("Appearance") {
            Picker("Theme", selection: $vm.themeMode) {
                ForEach(ThemeMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .onChange(of: appVM.themeMode) { _, newValue in
                appVM.updateTheme(newValue)
            }

            Toggle("Thinking Mode", isOn: $vm.thinkingModeEnabled)
                .tint(.terminalGreen)
                .onChange(of: appVM.thinkingModeEnabled) { _, newValue in
                    appVM.updateThinkingMode(newValue)
                }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Constants.appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Protocol")
                Spacer()
                Text("v\(Constants.protocolVersion)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch appVM.connectionState {
        case .connected: .statusOnline
        case .connecting: .orange
        case .disconnected: .statusOffline
        case .error: .red
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppViewModel.preview)
        .preferredColorScheme(.dark)
}
