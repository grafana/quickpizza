import Foundation
import SwiftiePod

let pizzaRepositoryProvider = Provider<PizzaRepositoryProtocol> { pod in
    PizzaRepository(
        apiClient: pod.resolve(apiClientProvider),
        debugSettings: pod.resolve(debugSettingsRepositoryProvider),
        logger: pod.resolve(loggerProvider),
        tracer: pod.resolve(tracerProvider)
    )
}

/// Concrete implementation of PizzaRepositoryProtocol.
final class PizzaRepository: PizzaRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let debugSettings: DebugSettingsRepository
    private let logger: Logging
    private let tracer: Tracing

    init(apiClient: APIClientProtocol, debugSettings: DebugSettingsRepository, logger: Logging, tracer: Tracing) {
        self.apiClient = apiClient
        self.debugSettings = debugSettings
        self.logger = logger
        self.tracer = tracer
    }

    func getQuote() async -> String {
        do {
            let (data, response) = try await apiClient.get("/api/quotes")
            if response.statusCode == 200 {
                struct QuotesResponse: Decodable { let quotes: [String] }
                let result = try JSONDecoder().decode(QuotesResponse.self, from: data)
                if let quote = result.quotes.first {
                    logger.debug("Quote fetched successfully")
                    return quote
                }
            }
        } catch {
            logger.error("Failed to fetch quote", error: error)
        }
        return ""
    }

    func getTools() async -> [String] {
        do {
            let (data, response) = try await apiClient.get("/api/tools")
            if response.statusCode == 200 {
                struct ToolsResponse: Decodable { let tools: [String] }
                let result = try JSONDecoder().decode(ToolsResponse.self, from: data)
                logger.debug("Tools fetched", attributes: ["count": "\(result.tools.count)"])
                return result.tools
            } else if response.statusCode == 401 {
                logger.debug("Tools fetch requires authentication")
            }
        } catch {
            logger.error("Failed to fetch tools", error: error)
        }
        return []
    }

    func getRecommendation(_ restrictions: Restrictions) async throws -> PizzaRecommendation? {
        try await tracer.withActiveSpan("pizza.get_recommendation", kind: .client) { span in
            span.setAttribute(key: "pizza.vegetarian", value: restrictions.mustBeVegetarian)
            span.setAttribute(key: "pizza.max_calories", value: restrictions.maxCaloriesPerSlice)

            let (data, response) = try await apiClient.post("/api/pizza", body: restrictions)
            span.setAttribute(key: "http.status_code", value: response.statusCode)

            if response.statusCode == 200 {
                let recommendation: PizzaRecommendation
                if debugSettings.current.useV2PizzaSchema {
                    recommendation = try parseRecommendationV2(data)
                } else {
                    recommendation = try JSONDecoder().decode(PizzaRecommendation.self, from: data)
                }
                span.setAttribute(key: "pizza.id", value: recommendation.pizza.id)
                span.setAttribute(key: "pizza.name", value: recommendation.pizza.name)
                logger.info("Pizza recommendation fetched", attributes: [
                    "pizza_id": "\(recommendation.pizza.id)",
                    "pizza_name": recommendation.pizza.name,
                ])
                return recommendation
            } else if response.statusCode == 401 {
                logger.warning("Pizza recommendation requires authentication")
                return nil
            } else if response.statusCode == 403 {
                struct ErrorResponse: Decodable { let error: String? }
                let errorResp = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let message = errorResp?.error ?? "Operation not permitted"
                throw PizzaError.forbidden(message)
            } else if response.statusCode >= 500 {
                throw PizzaError.serverError
            }
            return nil
        }
    }

    /// Parses the upcoming v2 response schema. v2 renames `pizza.name` → `pizza.displayName`
    /// and `pizza.tool` → `pizza.tooling`.
    private func parseRecommendationV2(_ data: Data) throws -> PizzaRecommendation {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pizzaObj = root["pizza"] as? [String: Any] else {
            throw PizzaError.v2SchemaError("missing 'pizza' object")
        }
        guard let id = pizzaObj["id"] as? Int else {
            throw PizzaError.v2SchemaError("missing required int field 'id'")
        }
        guard let displayName = pizzaObj["displayName"] as? String else {
            throw PizzaError.v2SchemaError("missing required string field 'displayName'")
        }
        guard let tooling = pizzaObj["tooling"] as? String else {
            throw PizzaError.v2SchemaError("missing required string field 'tooling'")
        }

        let ingredients: [Ingredient]
        if let ingredientsArray = pizzaObj["ingredients"] as? [[String: Any]] {
            ingredients = ingredientsArray.compactMap { dict in
                guard let iId = (dict["ID"] as? Int) ?? (dict["id"] as? Int),
                      let name = dict["name"] as? String else { return nil }
                return Ingredient(
                    id: iId,
                    name: name,
                    caloriesPerSlice: dict["caloriesPerSlice"] as? Int,
                    vegetarian: dict["vegetarian"] as? Bool
                )
            }
        } else {
            ingredients = []
        }

        var dough: Dough?
        if let doughObj = pizzaObj["dough"] as? [String: Any],
           let dId = (doughObj["ID"] as? Int) ?? (doughObj["id"] as? Int),
           let dName = doughObj["name"] as? String {
            dough = Dough(id: dId, name: dName, caloriesPerSlice: doughObj["caloriesPerSlice"] as? Int)
        }

        let pizza = Pizza(
            id: id,
            name: displayName,
            dough: dough ?? Dough(id: 0, name: "Unknown"),
            ingredients: ingredients,
            tool: tooling
        )
        return PizzaRecommendation(
            pizza: pizza,
            calories: root["calories"] as? Int,
            vegetarian: root["vegetarian"] as? Bool
        )
    }

    func ratePizza(pizzaId: Int, stars: Int) async throws {
        try await tracer.withActiveSpan("pizza.rate", kind: .client) { span in
            span.setAttribute(key: "pizza.id", value: pizzaId)
            span.setAttribute(key: "pizza.stars", value: stars)

            let body = RatingRequest(pizzaId: pizzaId, stars: stars)
            let (_, response) = try await apiClient.post("/api/ratings", body: body)
            span.setAttribute(key: "http.status_code", value: response.statusCode)

            if response.statusCode == 200 || response.statusCode == 201 {
                logger.info("Pizza rated", attributes: [
                    "pizza_id": "\(pizzaId)",
                    "stars": "\(stars)",
                ])
            } else {
                logger.warning("Failed to rate pizza", attributes: [
                    "status_code": "\(response.statusCode)",
                ])
                throw PizzaError.ratingFailed
            }
        }
    }
}

enum PizzaError: LocalizedError {
    case forbidden(String)
    case serverError
    case ratingFailed
    case v2SchemaError(String)

    var errorDescription: String? {
        switch self {
        case .forbidden(let msg): return msg
        case .serverError: return "Server error — please try again later"
        case .ratingFailed: return "Failed to submit rating"
        case .v2SchemaError(let detail): return "v2 schema parse error: \(detail)"
        }
    }
}
