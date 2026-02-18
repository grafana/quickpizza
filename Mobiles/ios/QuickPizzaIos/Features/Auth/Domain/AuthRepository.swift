import Foundation
import SwiftiePod

let authRepositoryProvider = Provider<AuthServiceProtocol> { pod in
    AuthRepository(
        apiClient: pod.resolve(apiClientProvider),
        tokenStorage: pod.resolve(tokenStorageProvider),
        logger: pod.resolve(loggerProvider),
        tracer: pod.resolve(tracerProvider)
    )
}

/// Concrete implementation of AuthServiceProtocol using the QuickPizza API.
final class AuthRepository: AuthServiceProtocol {
    private let apiClient: APIClientProtocol
    private let tokenStorage: TokenStoring
    private let logger: Logging
    private let tracer: Tracing

    private let authStateContinuation: AsyncStream<Void>.Continuation
    let authStateChanged: AsyncStream<Void>

    init(
        apiClient: APIClientProtocol,
        tokenStorage: TokenStoring,
        logger: Logging,
        tracer: Tracing
    ) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
        self.logger = logger
        self.tracer = tracer

        var continuation: AsyncStream<Void>.Continuation!
        self.authStateChanged = AsyncStream { continuation = $0 }
        self.authStateContinuation = continuation
    }

    var isAuthenticated: Bool {
        tokenStorage.loadSession().isAuthenticated
    }

    var currentUsername: String? {
        tokenStorage.loadSession().username
    }

    func login(username: String, password: String) async -> Bool {
        do {
            return try await tracer.withActiveSpan("auth.login", kind: .client) { span in
                span.setAttribute(key: "user.name", value: username)

                struct LoginBody: Encodable {
                    let username: String
                    let password: String
                }

                let (data, response) = try await apiClient.post(
                    "/api/users/token/login",
                    body: LoginBody(username: username, password: password),
                    includeAuth: false
                )

                span.setAttribute(key: "http.status_code", value: response.statusCode)

                if response.statusCode == 200 {
                    struct LoginResponse: Decodable {
                        let token: String
                    }

                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    tokenStorage.saveSession(token: loginResponse.token, username: username)
                    apiClient.refreshToken()
                    span.setAttribute(key: "auth.result", value: "success")
                    authStateContinuation.yield(())
                    logger.info("Login successful", attributes: ["username": username])
                    return true
                } else {
                    span.setAttribute(key: "auth.result", value: "failed")
                    logger.warning("Login failed", attributes: [
                        "username": username,
                        "status_code": "\(response.statusCode)",
                    ])
                    return false
                }
            }
        } catch {
            logger.error("Login error", error: error, attributes: ["username": username])
            return false
        }
    }

    func logout() {
        tokenStorage.clearSession()
        apiClient.refreshToken()
        authStateContinuation.yield(())
        logger.info("User logged out")
    }

    func loadSession() -> StoredSession {
        tokenStorage.loadSession()
    }
}
