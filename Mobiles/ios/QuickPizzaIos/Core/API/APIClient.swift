import Foundation
import SwiftiePod

let apiClientProvider = Provider<APIClientProtocol> { pod in
    let config = pod.resolve(configServiceProvider)
    return APIClient(
        baseURL: config.baseURL,
        tokenStorage: pod.resolve(tokenStorageProvider),
        logger: pod.resolve(loggerProvider)
    )
}

/// URLSession-based HTTP client with auth token injection and observability.
final class APIClient: APIClientProtocol {
    private let baseURL: String
    private let tokenStorage: TokenStoring
    private let logger: Logging
    private let session: URLSession
    private let timeout: TimeInterval = 10

    private var cachedToken: String?

    init(
        baseURL: String,
        tokenStorage: TokenStoring,
        logger: Logging
    ) {
        self.baseURL = baseURL
        self.tokenStorage = tokenStorage
        self.logger = logger
        self.session = URLSession.shared

        // Load initial token
        let stored = tokenStorage.loadSession()
        self.cachedToken = stored.token
    }

    var isAuthenticated: Bool {
        cachedToken != nil && !(cachedToken?.isEmpty ?? true)
    }

    var currentToken: String? {
        cachedToken
    }

    func refreshToken() {
        let stored = tokenStorage.loadSession()
        cachedToken = stored.token
    }

    // MARK: - HTTP Methods

    func get(_ endpoint: String) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(endpoint)
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        applyHeaders(to: &request, includeAuth: true)
        return try await perform(request, endpoint: endpoint)
    }

    func post(_ endpoint: String, body: Encodable? = nil, includeAuth: Bool = true) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(endpoint)
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        applyHeaders(to: &request, includeAuth: includeAuth)

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return try await perform(request, endpoint: endpoint)
    }

    func delete(_ endpoint: String) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(endpoint)
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "DELETE"
        applyHeaders(to: &request, includeAuth: true)
        return try await perform(request, endpoint: endpoint)
    }

    // MARK: - Private

    private func buildURL(_ endpoint: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL(endpoint)
        }
        return url
    }

    private func applyHeaders(to request: inout URLRequest, includeAuth: Bool) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if includeAuth, let token = cachedToken, !token.isEmpty {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func perform(_ request: URLRequest, endpoint: String) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            return (data, httpResponse)
        } catch let error as APIError {
            throw error
        } catch {
            logger.error(
                "API \(request.httpMethod ?? "?") \(endpoint) failed",
                error: error,
                attributes: ["endpoint": endpoint]
            )
            throw APIError.networkError(error)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case networkError(Error)
    case httpError(statusCode: Int, data: Data)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid server response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, _):
            return "HTTP error \(code)"
        }
    }
}
