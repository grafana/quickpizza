import Foundation
import SwiftiePod

let tokenStorageProvider = Provider<TokenStoring> { _ in
    UserDefaultsTokenStorage()
}

/// UserDefaults-based implementation of TokenStoring.
final class UserDefaultsTokenStorage: TokenStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveSession(token: String, username: String) {
        defaults.set(token, forKey: "auth_token")
        defaults.set(username, forKey: "auth_username")
    }

    func loadSession() -> StoredSession {
        StoredSession(
            token: defaults.string(forKey: "auth_token"),
            username: defaults.string(forKey: "auth_username")
        )
    }

    func clearSession() {
        defaults.removeObject(forKey: "auth_token")
        defaults.removeObject(forKey: "auth_username")
    }
}
