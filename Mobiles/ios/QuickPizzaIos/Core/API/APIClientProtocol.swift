import Foundation

/// Protocol for the HTTP API client.
protocol APIClientProtocol {
    /// Perform a GET request.
    func get(_ endpoint: String) async throws -> (Data, HTTPURLResponse)

    /// Perform a POST request with an optional JSON body.
    func post(_ endpoint: String, body: Encodable?, includeAuth: Bool) async throws -> (Data, HTTPURLResponse)

    /// Perform a DELETE request.
    func delete(_ endpoint: String) async throws -> (Data, HTTPURLResponse)

    /// Whether the user is currently authenticated.
    var isAuthenticated: Bool { get }

    /// Current auth token, if any.
    var currentToken: String? { get }

    /// Refresh the cached token from storage.
    func refreshToken()
}

extension APIClientProtocol {
    func post(_ endpoint: String, body: Encodable? = nil, includeAuth: Bool = true) async throws -> (Data, HTTPURLResponse) {
        try await post(endpoint, body: body, includeAuth: includeAuth)
    }
}
