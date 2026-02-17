import Foundation

/// Protocol for pizza-related API operations.
protocol PizzaRepositoryProtocol {
    /// Fetch a random quote.
    func getQuote() async -> String

    /// Fetch available tools for pizza making.
    func getTools() async -> [String]

    /// Get a pizza recommendation based on restrictions.
    func getRecommendation(_ restrictions: Restrictions) async throws -> PizzaRecommendation?

    /// Submit a rating for a pizza.
    func ratePizza(pizzaId: Int, stars: Int) async throws
}
