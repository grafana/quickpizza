import Foundation

/// Stored session data.
struct StoredSession: Equatable {
    let token: String?
    let username: String?

    static let empty = StoredSession(token: nil, username: nil)

    var isAuthenticated: Bool {
        token != nil && !(token?.isEmpty ?? true)
    }
}

/// Protocol for persisting auth tokens and session data.
protocol TokenStoring {
    func saveSession(token: String, username: String)
    func loadSession() -> StoredSession
    func clearSession()
}
