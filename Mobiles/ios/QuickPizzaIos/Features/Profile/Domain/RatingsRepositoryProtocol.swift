import Foundation

/// Protocol for ratings-related API operations.
protocol RatingsRepositoryProtocol {
    /// Fetch all ratings for the current user.
    func getRatings() async throws -> [Rating]

    /// Clear all ratings for the current user.
    func clearRatings() async throws
}
