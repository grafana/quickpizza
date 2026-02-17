import SwiftUI
import SwiftiePod

let profileViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    ProfileViewModel(
        authService: pod.resolve(authRepositoryProvider),
        ratingsRepository: pod.resolve(ratingsRepositoryProvider),
        logger: pod.resolve(loggerProvider)
    )
}

@Observable
class ProfileViewModel {
    private let authService: AuthServiceProtocol
    private let ratingsRepository: RatingsRepositoryProtocol
    private let logger: Logging

    // View state
    var ratings: [Rating] = []
    var isLoading = false
    var errorMessage: String?
    var didLogout = false

    init(
        authService: AuthServiceProtocol,
        ratingsRepository: RatingsRepositoryProtocol,
        logger: Logging
    ) {
        self.authService = authService
        self.ratingsRepository = ratingsRepository
        self.logger = logger
    }

    var username: String {
        authService.currentUsername ?? "Unknown"
    }

    var pizzaCount: Int {
        ratings.count
    }

    /// Called from .task { } when the view appears.
    func start() async {
        await loadRatings()
    }

    func loadRatings() async {
        isLoading = true
        do {
            ratings = try await ratingsRepository.getRatings()
        } catch {
            logger.error("Failed to load ratings", error: error)
            errorMessage = "Failed to load ratings"
        }
        isLoading = false
    }

    func clearRatings() async {
        do {
            try await ratingsRepository.clearRatings()
            ratings = []
            logger.info("Ratings cleared by user")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to clear ratings", error: error)
        }
    }

    func signOut() {
        authService.logout()
        didLogout = true
        logger.info("User signed out")
    }
}
