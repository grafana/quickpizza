import Foundation
import SwiftiePod

let ratingsRepositoryProvider = Provider<RatingsRepositoryProtocol> { pod in
    RatingsRepository(
        apiClient: pod.resolve(apiClientProvider),
        logger: pod.resolve(loggerProvider)
    )
}

/// Concrete implementation of RatingsRepositoryProtocol.
final class RatingsRepository: RatingsRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let logger: Logging

    init(apiClient: APIClientProtocol, logger: Logging) {
        self.apiClient = apiClient
        self.logger = logger
    }

    func getRatings() async throws -> [Rating] {
        let (data, response) = try await apiClient.get("/api/ratings")

        if response.statusCode == 200 {
            struct RatingsResponse: Decodable { let ratings: [Rating] }
            let result = try JSONDecoder().decode(RatingsResponse.self, from: data)
            logger.debug("Ratings fetched", attributes: ["count": "\(result.ratings.count)"])
            return result.ratings
        } else if response.statusCode == 401 {
            logger.debug("Ratings fetch requires authentication")
            return []
        }
        return []
    }

    func clearRatings() async throws {
        let (data, response) = try await apiClient.delete("/api/ratings")

        if response.statusCode == 200 || response.statusCode == 204 {
            logger.info("All ratings cleared")
        } else if response.statusCode == 401 {
            logger.warning("Clear ratings requires authentication")
            throw RatingsError.unauthorized
        } else if response.statusCode == 403 {
            let serverMessage = Self.parseErrorMessage(from: data)
            let message = serverMessage ?? "You don't have permission to do this operation"
            logger.warning("Clear ratings forbidden", attributes: [
                "error": message,
            ])
            throw RatingsError.forbidden(message)
        } else {
            logger.warning("Failed to clear ratings", attributes: [
                "status_code": "\(response.statusCode)",
            ])
            throw RatingsError.clearFailed
        }
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? String else {
            return nil
        }
        return error
    }
}

enum RatingsError: LocalizedError {
    case clearFailed
    case unauthorized
    case forbidden(String)

    var errorDescription: String? {
        switch self {
        case .clearFailed: return "Failed to clear ratings"
        case .unauthorized: return "You may need to be logged in"
        case .forbidden(let message): return message
        }
    }
}
