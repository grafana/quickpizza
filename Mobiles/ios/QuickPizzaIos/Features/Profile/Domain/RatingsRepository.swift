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
        let (_, response) = try await apiClient.delete("/api/ratings")

        if response.statusCode == 200 {
            logger.info("All ratings cleared")
        } else {
            logger.warning("Failed to clear ratings", attributes: [
                "status_code": "\(response.statusCode)",
            ])
            throw RatingsError.clearFailed
        }
    }
}

enum RatingsError: LocalizedError {
    case clearFailed

    var errorDescription: String? {
        switch self {
        case .clearFailed: return "Failed to clear ratings"
        }
    }
}
