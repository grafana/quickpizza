import Foundation
import SwiftiePod

let tokenStorageProvider = Provider<TokenStoring> { _ in
    KeychainTokenStorage()
}

/// Keychain-based implementation of TokenStoring.
final class KeychainTokenStorage: TokenStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveSession(token: String, username: String) {
        AuthKeychain.save(token: token, username: username)
        defaults.set(username, forKey: "auth_username")
        defaults.removeObject(forKey: "auth_token")
    }

    func loadSession() -> StoredSession {
        StoredSession(
            token: AuthKeychain.readToken(),
            username: AuthKeychain.readUsername() ?? defaults.string(forKey: "auth_username")
        )
    }

    func clearSession() {
        AuthKeychain.clear()
        defaults.removeObject(forKey: "auth_username")
        defaults.removeObject(forKey: "auth_token")
    }
}
