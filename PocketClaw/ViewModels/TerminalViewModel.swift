import Foundation
import SwiftTerm

// MARK: - Terminal ViewModel

@Observable
final class TerminalViewModel {
    // MARK: - Connection State

    var connectionState: SSHConnectionState = .disconnected
    var host: String = ""
    var port: String = "22"
    var username: String = ""
    var password: String = ""
    var errorMessage: String?

    // MARK: - Terminal State

    /// Whether a PTY session is active (connected and terminal is showing)
    var isTerminalActive: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    // MARK: - Private

    private let sshService = SSHService()

    /// Strong reference to the terminal view — kept alive across sheet dismiss/reopen
    /// so the terminal buffer (scrollback, cursor position, etc.) persists.
    /// Created lazily by TerminalContainerView and reused on subsequent presentations.
    var terminalView: TerminalView?

    /// Whether credentials have been loaded from Keychain already
    private var hasLoadedCredentials = false

    // MARK: - Init

    init() {
        setupCallbacks()
    }

    // MARK: - Load Saved Credentials

    func loadSavedCredentials() {
        guard !hasLoadedCredentials else { return }
        hasLoadedCredentials = true

        host = KeychainService.shared.loadSSHHost() ?? ""
        username = KeychainService.shared.loadSSHUsername() ?? ""
        password = KeychainService.shared.loadSSHPassword() ?? ""
        if let savedPort = KeychainService.shared.loadSSHPort() {
            port = String(savedPort)
        }
    }

    // MARK: - Save Credentials

    /// Persists current form values to Keychain so they survive app restarts.
    func saveCredentials() {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedUser = username.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty, !trimmedUser.isEmpty else { return }

        do {
            try KeychainService.shared.saveSSHHost(trimmedHost)
            try KeychainService.shared.saveSSHUsername(trimmedUser)
            if !password.isEmpty {
                try KeychainService.shared.saveSSHPassword(password)
            }
            if let portNum = Int(port), portNum > 0, portNum <= 65535 {
                try KeychainService.shared.saveSSHPort(portNum)
            }
        } catch {
            // Non-fatal
        }
    }

    // MARK: - Pre-fill Host from Server URL

    func prefillHost(from serverURL: String) {
        // Only pre-fill if host is empty (no saved credentials)
        guard host.isEmpty else { return }

        // Extract hostname from wss://host:port or wss://host
        var urlString = serverURL
        // Remove ws:// or wss:// prefix
        if urlString.hasPrefix("wss://") {
            urlString = String(urlString.dropFirst(6))
        } else if urlString.hasPrefix("ws://") {
            urlString = String(urlString.dropFirst(5))
        }
        // Remove port if present
        if let colonIndex = urlString.firstIndex(of: ":") {
            urlString = String(urlString[urlString.startIndex..<colonIndex])
        }
        // Remove path if present
        if let slashIndex = urlString.firstIndex(of: "/") {
            urlString = String(urlString[urlString.startIndex..<slashIndex])
        }

        if !urlString.isEmpty {
            host = urlString
        }
    }

    // MARK: - Connect

    func connect() async {
        errorMessage = nil

        guard !host.isEmpty else {
            errorMessage = "Host is required"
            return
        }
        guard !username.isEmpty else {
            errorMessage = "Username is required"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Password is required"
            return
        }
        guard let portNum = Int(port), portNum > 0, portNum <= 65535 else {
            errorMessage = "Invalid port number"
            return
        }

        // Save credentials to Keychain
        saveCredentials()

        do {
            try await sshService.connect(
                host: host,
                port: portNum,
                username: username,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        sshService.disconnect()
    }

    // MARK: - Send Data (terminal keyboard → SSH)

    func send(_ data: Data) {
        sshService.send(data)
    }

    // MARK: - Resize

    func resize(cols: Int, rows: Int) {
        sshService.resize(cols: cols, rows: rows)
    }

    // MARK: - Clear Saved Credentials

    func clearCredentials() {
        try? KeychainService.shared.deleteSSHCredentials()
        host = ""
        port = "22"
        username = ""
        password = ""
    }

    // MARK: - Private

    private func setupCallbacks() {
        sshService.onStateChanged = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.connectionState = state
                if case .error(let msg) = state {
                    self?.errorMessage = msg
                }
            }
        }

        sshService.onDataReceived = { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self, let terminalView = self.terminalView else { return }
                let bytes = Array(data)
                terminalView.feed(byteArray: bytes[...])
            }
        }
    }
}
