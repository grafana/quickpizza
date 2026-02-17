import Foundation

/// Protocol for authentication operations.
protocol AuthServiceProtocol {
    /// Attempt login with username and password.
    /// Returns true on success, false on failure.
    func login(username: String, password: String) async -> Bool

    /// Log out the current user.
    func logout()

    /// Load the saved session from storage.
    func loadSession() -> StoredSession

    /// Whether the user is currently authenticated.
    var isAuthenticated: Bool { get }

    /// Current username, if logged in.
    var currentUsername: String? { get }
}
