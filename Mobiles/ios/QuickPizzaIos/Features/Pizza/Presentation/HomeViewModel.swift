import SwiftUI
import SwiftiePod

let homeViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    HomeViewModel(
        pizzaRepository: pod.resolve(pizzaRepositoryProvider),
        authService: pod.resolve(authRepositoryProvider),
        logger: pod.resolve(loggerProvider)
    )
}

@Observable
class HomeViewModel {
    private let pizzaRepository: PizzaRepositoryProtocol
    private let authService: AuthServiceProtocol
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
        logger: Logging
    ) {
        self.pizzaRepository = pizzaRepository
        self.authService = authService
        self.logger = logger
    }

    var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    /// Called from .task { } when the view appears.
    /// Loads initial data and listens for logout events.
    /// Auto-cancelled when the view disappears (structured concurrency).
    func start() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await self.loadInitialData()
            }
            group.addTask { @MainActor in
                for await _ in self.authService.authStateChanged {
                    if !self.authService.isAuthenticated {
                        self.clearRecommendationState()
                    }
                }
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
    
    /// Clears the pizza recommendation and any errors.
    /// Called when the user logs out.
    func clearRecommendationState() {
        recommendation = nil
        errorMessage = nil
        ratingSubmitted = false
    }
}
