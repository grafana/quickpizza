import SwiftUI

/// Displays a pizza recommendation result.
struct PizzaCard: View {
    let recommendation: PizzaRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pizza name header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(AppColors.primary)
                Text(recommendation.pizza.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Divider()

            // Dough
            DetailRow(icon: "circle.fill", label: "Dough", value: recommendation.pizza.dough.name)

            // Ingredients
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.success)
                    Text("Ingredients")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textSecondary)
                }
                
                FlowLayout(spacing: 8) {
                    ForEach(recommendation.pizza.ingredients, id: \.id) { ingredient in
                        Text(ingredient.name)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                }
            }

            // Tool
            DetailRow(icon: "wrench.fill", label: "Tool", value: recommendation.pizza.tool)

            // Calories & Vegetarian
            HStack(spacing: 16) {
                if let calories = recommendation.calories {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColors.primary)
                        Text("\(calories) cal/slice")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                if recommendation.vegetarian == true {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("Vegetarian")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .cardStyle()
    }

}

/// A key-value detail row with an SF Symbol icon.
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

#Preview {
    let sampleIngredients = [
        Ingredient(id: 1, name: "Jalapeños"),
        Ingredient(id: 2, name: "Extra cheese"),
        Ingredient(id: 3, name: "Fresh basil"),
        Ingredient(id: 4, name: "Olive oil"),
        Ingredient(id: 5, name: "San Marzano tomatoes"),
        Ingredient(id: 6, name: "Mozzarella")
    ]
    
    let sampleDough = Dough(id: 1, name: "Thin")
    
    let samplePizza = Pizza(
        id: 1,
        name: "A Misty Quattro Stagioni",
        dough: sampleDough,
        ingredients: sampleIngredients,
        tool: "Knife"
    )
    
    let sampleRecommendation = PizzaRecommendation(
        pizza: samplePizza,
        calories: 425,
        vegetarian: true
    )
    
    PizzaCard(recommendation: sampleRecommendation)
        .padding()
}
