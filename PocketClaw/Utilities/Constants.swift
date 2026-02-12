import Foundation

// MARK: - App Constants

enum Constants {
    static let appName = "PocketClaw"
    static let appVersion = "1.0.0"
    static let protocolVersion = 3
    static let defaultPort = 18789
    static let defaultScheme = "wss"

    // MARK: - Chat

    static let maxMessageLength = 4000
    static let messageWarningThreshold = 0.9

    // MARK: - Networking

    static let requestTimeoutSeconds: TimeInterval = 30
    static let maxReconnectAttempts = 5
    /// Patterns checked against uppercased message content to filter heartbeat noise.
    static let heartbeatFilterPatterns = [
        "HEARTBEAT_OK",
        "READ HEARTBEAT.MD",
        "# HEARTBEAT - EVENT-DRIVEN STATUS"
    ]

    // MARK: - Client Info

    static let clientId = "gateway-client"
    static let clientDisplayName = "PocketClaw"
    static let clientPlatform = "ios"
    static let clientMode = "backend"
    static let clientRole = "operator"

    // MARK: - Persistence Keys

    enum UserDefaultsKeys {
        static let serverURL = "serverURL"
        static let authMode = "authMode"
        static let themeMode = "themeMode"
        static let thinkingModeEnabled = "thinkingModeEnabled"
        static let onboardingCompleted = "onboardingCompleted"
    }

    enum KeychainKeys {
        static let serviceName = "dev.azam.PocketClaw"
        static let gatewayToken = "gatewayToken"
        static let gatewayPassword = "gatewayPassword"
        static let sshHost = "sshHost"
        static let sshPort = "sshPort"
        static let sshUsername = "sshUsername"
        static let sshPassword = "sshPassword"
    }
}
