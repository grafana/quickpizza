import Foundation

struct Pizza: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let dough: Dough
    let ingredients: [Ingredient]
    let tool: String
}

struct Dough: Codable, Equatable {
    let id: Int
    let name: String
    let caloriesPerSlice: Int?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name
        case caloriesPerSlice
    }

    init(id: Int, name: String, caloriesPerSlice: Int? = nil) {
        self.id = id
        self.name = name
        self.caloriesPerSlice = caloriesPerSlice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both "ID" (uppercase) and "id" (lowercase) for compatibility
        if let upperId = try? container.decode(Int.self, forKey: .id) {
            self.id = upperId
        } else {
            let altContainer = try decoder.container(keyedBy: AlternateCodingKeys.self)
            self.id = try altContainer.decode(Int.self, forKey: .id)
        }
        self.name = try container.decode(String.self, forKey: .name)
        self.caloriesPerSlice = try container.decodeIfPresent(Int.self, forKey: .caloriesPerSlice)
    }

    private enum AlternateCodingKeys: String, CodingKey {
        case id
    }
}

struct Ingredient: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let caloriesPerSlice: Int?
    let vegetarian: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name
        case caloriesPerSlice
        case vegetarian
    }

    init(id: Int, name: String, caloriesPerSlice: Int? = nil, vegetarian: Bool? = nil) {
        self.id = id
        self.name = name
        self.caloriesPerSlice = caloriesPerSlice
        self.vegetarian = vegetarian
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let upperId = try? container.decode(Int.self, forKey: .id) {
            self.id = upperId
        } else {
            let altContainer = try decoder.container(keyedBy: AlternateCodingKeys.self)
            self.id = try altContainer.decode(Int.self, forKey: .id)
        }
        self.name = try container.decode(String.self, forKey: .name)
        self.caloriesPerSlice = try container.decodeIfPresent(Int.self, forKey: .caloriesPerSlice)
        self.vegetarian = try container.decodeIfPresent(Bool.self, forKey: .vegetarian)
    }

    private enum AlternateCodingKeys: String, CodingKey {
        case id
    }
}

struct PizzaRecommendation: Codable, Equatable {
    let pizza: Pizza
    let calories: Int?
    let vegetarian: Bool?
}
