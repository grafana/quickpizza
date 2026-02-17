import Foundation

struct Rating: Codable, Equatable, Identifiable {
    let id: Int
    let pizzaId: Int
    let stars: Int

    enum CodingKeys: String, CodingKey {
        case id
        case pizzaId = "pizza_id"
        case stars
    }
}

/// Request body for submitting a rating.
struct RatingRequest: Codable {
    let pizzaId: Int
    let stars: Int

    enum CodingKeys: String, CodingKey {
        case pizzaId = "pizza_id"
        case stars
    }
}
