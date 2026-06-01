import SwiftUI
import SwiftiePod

let homeViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    HomeViewModel(
        pizzaRepository: pod.resolve(pizzaRepositoryProvider),
        authService: pod.resolve(authRepositoryProvider),
        debugSettings: pod.resolve(debugSettingsRepositoryProvider),
        logger: pod.resolve(loggerProvider)
    )
}

@Observable
class HomeViewModel {
    private let pizzaRepository: PizzaRepositoryProtocol
    private let authService: AuthServiceProtocol
    private let debugSettings: DebugSettingsRepository
    private let logger: Logging

    // View state
    var quote: String = ""
    var availableTools: [String] = []
    var restrictions = Restrictions.default
    var recommendation: PizzaRecommendation?
    var isLoading = false
    var errorMessage: String?
    var ratingSubmitted = false

    init(
        pizzaRepository: PizzaRepositoryProtocol,
        authService: AuthServiceProtocol,
        debugSettings: DebugSettingsRepository,
        logger: Logging
    ) {
        self.pizzaRepository = pizzaRepository
        self.authService = authService
        self.debugSettings = debugSettings
        self.logger = logger
    }

    var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    /// Called from .task { } when the view appears.
    /// Loads initial data and listens for logout events.
    /// Auto-cancelled when the view disappears (structured concurrency).
    func start() async {
        if !isAuthenticated {
            clearRecommendationState()
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await self.loadInitialData()
            }
            group.addTask { @MainActor in
                await self.observeAuthState()
            }
        }
    }

    func loadInitialData() async {
        async let quoteTask = pizzaRepository.getQuote()
        async let toolsTask = pizzaRepository.getTools()

        let (fetchedQuote, fetchedTools) = await (quoteTask, toolsTask)
        quote = fetchedQuote
        availableTools = fetchedTools
    }

    /// Observes auth state changes. When the user logs in/out:
    ///  - Clears stale recommendation state on logout
    ///  - Refetches `/api/tools` (requires a valid token)
    ///
    /// The `skipAuthDepInTools` debug toggle disables the tools refresh
    /// to reproduce a real-world bug where the tools list goes stale.
    private func observeAuthState() async {
        for await _ in authService.authStateChanged {
            if authService.isAuthenticated {
                if errorMessage == "Please sign in to get pizza recommendations" {
                    errorMessage = nil
                }
            } else {
                clearRecommendationState()
            }
            if !debugSettings.current.skipAuthDepInTools {
                let tools = await pizzaRepository.getTools()
                availableTools = tools
            }
        }
    }

    func getRecommendation() async {
        isLoading = true
        errorMessage = nil
        ratingSubmitted = false
        recommendation = nil

        do {
            recommendation = try await pizzaRepository.getRecommendation(restrictions)
            if recommendation == nil && !isAuthenticated {
                errorMessage = "Please sign in to get pizza recommendations"
            }
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to get recommendation", error: error)
        }

        isLoading = false
    }

    func ratePizza(stars: Int) async {
        guard let pizza = recommendation?.pizza else { return }

        do {
            try await pizzaRepository.ratePizza(pizzaId: pizza.id, stars: stars)
            ratingSubmitted = true
            logger.info("Pizza rated", attributes: [
                "pizza_id": "\(pizza.id)",
                "stars": "\(stars)",
            ])
        } catch {
            errorMessage = "Failed to submit rating"
            logger.error("Rating failed", error: error)
        }
    }

    func toggleExcludedTool(_ tool: String) {
        if restrictions.excludedTools.contains(tool) {
            restrictions.excludedTools.removeAll { $0 == tool }
        } else {
            restrictions.excludedTools.append(tool)
        }
    }

    func clearRecommendationState() {
        recommendation = nil
        errorMessage = nil
        ratingSubmitted = false
    }
}
