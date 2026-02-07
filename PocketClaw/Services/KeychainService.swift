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

    // MARK: - Clear All

    func clearAll() throws {
        try keychain.removeAll()
    }
}
