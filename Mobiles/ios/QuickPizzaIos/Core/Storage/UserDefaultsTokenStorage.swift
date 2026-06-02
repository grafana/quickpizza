import Foundation
import SwiftiePod

let tokenStorageProvider = Provider<TokenStoring> { _ in
    UserDefaultsTokenStorage()
}

/// UserDefaults-based implementation of TokenStoring.
final class UserDefaultsTokenStorage: TokenStoring {
    private let defaults: UserDefaults
    private let tokenKey = "auth_token"
    private let usernameKey = "auth_username"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveSession(token: String, username: String) {
        defaults.set(token, forKey: tokenKey)
        defaults.set(username, forKey: usernameKey)
    }

    func loadSession() -> StoredSession {
        StoredSession(
            token: defaults.string(forKey: tokenKey),
            username: defaults.string(forKey: usernameKey)
        )
    }

    func clearSession() {
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: usernameKey)
    }
}
