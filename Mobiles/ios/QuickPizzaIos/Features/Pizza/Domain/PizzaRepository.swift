import Foundation
import OpenTelemetryApi
import SwiftiePod

let pizzaRepositoryProvider = Provider<PizzaRepositoryProtocol> { pod in
    PizzaRepository(
        apiClient: pod.resolve(apiClientProvider),
        logger: pod.resolve(loggerProvider),
        otelService: pod.resolve(otelServiceProvider)
    )
}

/// Concrete implementation of PizzaRepositoryProtocol.
final class PizzaRepository: PizzaRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let logger: Logging
    private let otelService: OTelService

    init(apiClient: APIClientProtocol, logger: Logging, otelService: OTelService) {
        self.apiClient = apiClient
        self.logger = logger
        self.otelService = otelService
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
        let tracer = otelService.getTracer()
        let span = tracer.spanBuilder(spanName: "pizza.get_recommendation").setSpanKind(spanKind: .client).startSpan()
        span.setAttribute(key: "pizza.vegetarian", value: restrictions.mustBeVegetarian)
        span.setAttribute(key: "pizza.max_calories", value: restrictions.maxCaloriesPerSlice)
        defer { span.end() }

        let (data, response) = try await apiClient.post("/api/pizza", body: restrictions)
        span.setAttribute(key: "http.status_code", value: response.statusCode)

        if response.statusCode == 200 {
            let recommendation = try JSONDecoder().decode(PizzaRecommendation.self, from: data)
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

    func ratePizza(pizzaId: Int, stars: Int) async throws {
        let tracer = otelService.getTracer()
        let span = tracer.spanBuilder(spanName: "pizza.rate").setSpanKind(spanKind: .client).startSpan()
        span.setAttribute(key: "pizza.id", value: pizzaId)
        span.setAttribute(key: "pizza.stars", value: stars)
        defer { span.end() }

        let body = RatingRequest(pizzaId: pizzaId, stars: stars)
        let (_, response) = try await apiClient.post("/api/ratings", body: body)
        span.setAttribute(key: "http.status_code", value: response.statusCode)

        if response.statusCode == 200 || response.statusCode == 201 {
            logger.info("Pizza rated", attributes: [
                "pizza_id": "\(pizzaId)",
                "stars": "\(stars)",
            ])
        } else {
            span.status = .error(description: "Rating failed with status \(response.statusCode)")
            logger.warning("Failed to rate pizza", attributes: [
                "status_code": "\(response.statusCode)",
            ])
            throw PizzaError.ratingFailed
        }
    }
}

enum PizzaError: LocalizedError {
    case forbidden(String)
    case serverError
    case ratingFailed

    var errorDescription: String? {
        switch self {
        case .forbidden(let msg): return msg
        case .serverError: return "Server error — please try again later"
        case .ratingFailed: return "Failed to submit rating"
        }
    }
}
