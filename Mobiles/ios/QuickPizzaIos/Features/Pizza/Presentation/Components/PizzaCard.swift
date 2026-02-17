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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.success)
                    Text("Ingredients")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Text(recommendation.pizza.ingredients.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
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
