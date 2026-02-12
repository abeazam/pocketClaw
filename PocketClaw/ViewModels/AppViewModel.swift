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

    // MARK: - Demo State

    /// True when running with canned data (not persisted — resets on app restart)
    var isDemoMode = false

    // MARK: - Reconnection

    var isReconnecting = false

    // MARK: - Cross-Tab References

    /// Agent view model reference for presence event dispatch
    var agentListViewModel: AgentListViewModel?

    // MARK: - Chat ViewModel Cache

    /// Keeps ChatViewModels alive across tab switches so streaming state isn't lost.
    private var chatViewModels: [String: ChatViewModel] = [:]

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

    // MARK: - Demo Mode

    func startDemoMode() {
        let demoClient = DemoClient()
        client = demoClient
        isDemoMode = true
        connectionState = .connected
        onboardingCompleted = true
        serverURL = "Demo Mode"
        authMode = "demo"
    }

    func exitDemoMode() {
        // Clean up cached chat view models
        for (_, vm) in chatViewModels {
            vm.stopListening()
        }
        chatViewModels.removeAll()

        client = nil
        isDemoMode = false
        connectionState = .disconnected
        onboardingCompleted = false
        serverURL = ""
        authMode = "token"
    }

    func connect() async {
        // Skip real connection in demo mode
        guard !isDemoMode else { return }

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
        // Clean up cached chat view models
        for (_, vm) in chatViewModels {
            vm.stopListening()
        }
        chatViewModels.removeAll()

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
        guard !isDemoMode else { return }
        guard !serverURL.isEmpty, !connectionState.isConnected else { return }
        // Don't reconnect if already connecting
        if case .connecting = connectionState { return }
        isReconnecting = true
        await connect()
        isReconnecting = false
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

    // MARK: - Chat ViewModel Management

    /// Returns a cached ChatViewModel for the given session key, creating one if needed.
    func chatViewModel(for sessionKey: String) -> ChatViewModel? {
        if let existing = chatViewModels[sessionKey] {
            return existing
        }
        guard let client else { return nil }
        let vm = ChatViewModel(client: client)
        vm.setThinkingEnabled(thinkingModeEnabled)
        vm.startListening(for: sessionKey)
        chatViewModels[sessionKey] = vm
        return vm
    }

    /// Remove a cached ChatViewModel (e.g. when session is deleted).
    func removeChatViewModel(for sessionKey: String) {
        chatViewModels[sessionKey]?.stopListening()
        chatViewModels.removeValue(forKey: sessionKey)
    }

    // MARK: - Event Handling

    private func handleEvent(eventName: String, payload: [String: Any]) {
        if eventName == "presence" {
            // Update agent status from presence events
            guard let agentId = payload["agentId"] as? String
                    ?? payload["agent"] as? String,
                  let status = payload["status"] as? String
                    ?? payload["state"] as? String else {
                return
            }
            if let vm = agentListViewModel {
                if let idx = vm.agents.firstIndex(where: { $0.id == agentId }) {
                    vm.agents[idx].status = status
                }
            }
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
