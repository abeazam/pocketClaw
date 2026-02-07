import SwiftUI

// MARK: - Connection State

enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting..."
        case .connected: "Connected"
        case .error(let message): "Error: \(message)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - App ViewModel

@Observable
final class AppViewModel {
    // MARK: - Connection State

    var connectionState: ConnectionState = .disconnected
    var serverURL: String = ""
    var authMode: String = "token"

    // MARK: - Client

    private(set) var client: OpenClawClient?

    // MARK: - Preferences

    var themeMode: ThemeMode = .dark
    var thinkingModeEnabled: Bool = false
    var onboardingCompleted: Bool = false

    // MARK: - Init

    init() {
        loadPersistedSettings()
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.onboardingCompleted)
    }

    // MARK: - Connection

    func saveConnectionSettings(url: String, authMode: AuthMode) {
        serverURL = url
        self.authMode = authMode.rawValue
        UserDefaults.standard.set(url, forKey: Constants.UserDefaultsKeys.serverURL)
        UserDefaults.standard.set(authMode.rawValue, forKey: Constants.UserDefaultsKeys.authMode)
    }

    func connect() async {
        guard !serverURL.isEmpty else {
            connectionState = .error("No server URL configured")
            return
        }

        guard let url = URL(string: serverURL) else {
            connectionState = .error("Invalid server URL")
            return
        }

        // Load credentials
        let token: String?
        let password: String?
        if authMode == "password" {
            token = nil
            password = KeychainService.shared.loadPassword()
        } else {
            token = KeychainService.shared.loadToken()
            password = nil
        }

        connectionState = .connecting

        // Create client
        let newClient = OpenClawClient(url: url, token: token, password: password)

        // Set up state handler
        newClient.setConnectionStateHandler { [weak self] state in
            Task { @MainActor in
                self?.connectionState = state
            }
        }

        // Set up event handler (will be used by child ViewModels later)
        newClient.setEventHandler { [weak self] eventName, payload in
            Task { @MainActor in
                self?.handleEvent(eventName: eventName, payload: payload)
            }
        }

        client = newClient

        do {
            try await newClient.connect()
        } catch {
            connectionState = .error(error.localizedDescription)
        }
    }

    func disconnect() {
        client?.disconnect()
        client = nil
        connectionState = .disconnected
        serverURL = ""
        authMode = "token"
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.serverURL)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.authMode)
        try? KeychainService.shared.clearAll()
    }

    /// Reconnect using saved credentials (e.g. on foreground)
    func reconnectIfNeeded() async {
        guard !serverURL.isEmpty, !connectionState.isConnected else { return }
        // Don't reconnect if already connecting
        if case .connecting = connectionState { return }
        await connect()
    }

    // MARK: - Preferences

    func updateTheme(_ mode: ThemeMode) {
        themeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Constants.UserDefaultsKeys.themeMode)
    }

    func updateThinkingMode(_ enabled: Bool) {
        thinkingModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Constants.UserDefaultsKeys.thinkingModeEnabled)
    }

    // MARK: - Event Handling

    private func handleEvent(eventName: String, payload: [String: Any]) {
        // Events will be dispatched to child ViewModels in later phases
        // For now, handle presence updates
        if eventName == "presence" {
            // Will be handled in Phase G (Agents)
        }
    }

    // MARK: - Private Methods

    private func loadPersistedSettings() {
        onboardingCompleted = UserDefaults.standard.bool(
            forKey: Constants.UserDefaultsKeys.onboardingCompleted
        )
        serverURL = UserDefaults.standard.string(
            forKey: Constants.UserDefaultsKeys.serverURL
        ) ?? ""
        authMode = UserDefaults.standard.string(
            forKey: Constants.UserDefaultsKeys.authMode
        ) ?? "token"

        if let themeName = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.themeMode),
           let mode = ThemeMode(rawValue: themeName) {
            themeMode = mode
        }

        thinkingModeEnabled = UserDefaults.standard.bool(
            forKey: Constants.UserDefaultsKeys.thinkingModeEnabled
        )
    }
}

// MARK: - Preview Support

extension AppViewModel {
    static var preview: AppViewModel {
        let vm = AppViewModel()
        vm.connectionState = .connected
        vm.serverURL = "wss://192.168.1.100:18789"
        vm.authMode = "token"
        vm.onboardingCompleted = true
        return vm
    }
}
