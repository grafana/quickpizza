import Foundation

/// Preferences for pizza recommendations.
struct Restrictions: Codable, Equatable {
    var maxCaloriesPerSlice: Int
    var mustBeVegetarian: Bool
    var excludedIngredients: [String]
    var excludedTools: [String]
    var maxNumberOfToppings: Int
    var minNumberOfToppings: Int
    var customName: String

    static let `default` = Restrictions(
        maxCaloriesPerSlice: 800,
        mustBeVegetarian: false,
        excludedIngredients: [],
        excludedTools: [],
        maxNumberOfToppings: 3,
        minNumberOfToppings: 1,
        customName: ""
    )
}
