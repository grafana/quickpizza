import SwiftUI
import SwiftiePod

let loginViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    LoginViewModel(
        authService: pod.resolve(authRepositoryProvider),
        logger: pod.resolve(loggerProvider)
    )
}

@Observable
class LoginViewModel {
    private let authService: AuthServiceProtocol
    private let logger: Logging

    // View state
    var username = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    var loginSucceeded = false

    init(authService: AuthServiceProtocol, logger: Logging) {
        self.authService = authService
        self.logger = logger
    }

    /// Check if already logged in and auto-dismiss.
    var isAlreadyLoggedIn: Bool {
        authService.isAuthenticated
    }

    func login() async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter username and password"
            return
        }

        isLoading = true
        errorMessage = nil

        let success = await authService.login(username: username, password: password)

        isLoading = false

        if success {
            loginSucceeded = true
        } else {
            errorMessage = "Login failed. Please check your credentials."
        }
    }
}
