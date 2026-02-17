import Foundation
import OpenTelemetryApi
import SwiftiePod

let authRepositoryProvider = Provider<AuthServiceProtocol> { pod in
    AuthRepository(
        apiClient: pod.resolve(apiClientProvider),
        tokenStorage: pod.resolve(tokenStorageProvider),
        logger: pod.resolve(loggerProvider),
        otelService: pod.resolve(otelServiceProvider)
    )
}

/// Concrete implementation of AuthServiceProtocol using the QuickPizza API.
final class AuthRepository: AuthServiceProtocol {
    private let apiClient: APIClientProtocol
    private let tokenStorage: TokenStoring
    private let logger: Logging
    private let otelService: OTelService

    init(
        apiClient: APIClientProtocol,
        tokenStorage: TokenStoring,
        logger: Logging,
        otelService: OTelService
    ) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
        self.logger = logger
        self.otelService = otelService
    }

    var isAuthenticated: Bool {
        tokenStorage.loadSession().isAuthenticated
    }

    var currentUsername: String? {
        tokenStorage.loadSession().username
    }

    func login(username: String, password: String) async -> Bool {
        let tracer = otelService.getTracer()
        let span = tracer.spanBuilder(spanName: "auth.login").setSpanKind(spanKind: .client).startSpan()
        span.setAttribute(key: "user.name", value: username)
        defer { span.end() }

        do {
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
        } catch {
            span.status = .error(description: error.localizedDescription)
            logger.error("Login error", error: error, attributes: ["username": username])
            return false
        }
    }

    func logout() {
        tokenStorage.clearSession()
        apiClient.refreshToken()
        logger.info("User logged out")
    }

    func loadSession() -> StoredSession {
        tokenStorage.loadSession()
    }
}
