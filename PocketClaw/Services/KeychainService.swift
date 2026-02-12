import Foundation
import KeychainAccess

// MARK: - Keychain Service

final class KeychainService {
    static let shared = KeychainService()

    private let keychain: Keychain

    private init() {
        keychain = Keychain(service: Constants.KeychainKeys.serviceName)
            .accessibility(.afterFirstUnlock)
    }

    // MARK: - Token

    func saveToken(_ token: String) throws {
        try keychain.set(token, key: Constants.KeychainKeys.gatewayToken)
    }

    func loadToken() -> String? {
        try? keychain.get(Constants.KeychainKeys.gatewayToken)
    }

    func deleteToken() throws {
        try keychain.remove(Constants.KeychainKeys.gatewayToken)
    }

    // MARK: - Password

    func savePassword(_ password: String) throws {
        try keychain.set(password, key: Constants.KeychainKeys.gatewayPassword)
    }

    func loadPassword() -> String? {
        try? keychain.get(Constants.KeychainKeys.gatewayPassword)
    }

    func deletePassword() throws {
        try keychain.remove(Constants.KeychainKeys.gatewayPassword)
    }

    // MARK: - SSH Host

    func saveSSHHost(_ host: String) throws {
        try keychain.set(host, key: Constants.KeychainKeys.sshHost)
    }

    func loadSSHHost() -> String? {
        try? keychain.get(Constants.KeychainKeys.sshHost)
    }

    // MARK: - SSH Port

    func saveSSHPort(_ port: Int) throws {
        try keychain.set(String(port), key: Constants.KeychainKeys.sshPort)
    }

    func loadSSHPort() -> Int? {
        guard let str = try? keychain.get(Constants.KeychainKeys.sshPort) else { return nil }
        return Int(str)
    }

    // MARK: - SSH Username

    func saveSSHUsername(_ username: String) throws {
        try keychain.set(username, key: Constants.KeychainKeys.sshUsername)
    }

    func loadSSHUsername() -> String? {
        try? keychain.get(Constants.KeychainKeys.sshUsername)
    }

    // MARK: - SSH Password

    func saveSSHPassword(_ password: String) throws {
        try keychain.set(password, key: Constants.KeychainKeys.sshPassword)
    }

    func loadSSHPassword() -> String? {
        try? keychain.get(Constants.KeychainKeys.sshPassword)
    }

    // MARK: - SSH Clear

    func deleteSSHCredentials() throws {
        try? keychain.remove(Constants.KeychainKeys.sshHost)
        try? keychain.remove(Constants.KeychainKeys.sshPort)
        try? keychain.remove(Constants.KeychainKeys.sshUsername)
        try? keychain.remove(Constants.KeychainKeys.sshPassword)
    }

    // MARK: - Clear All

    func clearAll() throws {
        try keychain.removeAll()
    }
}
