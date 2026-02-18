import SwiftUI
import SwiftiePod

struct HomeView: View {
    @State private var viewModel = pod.resolve(homeViewModelProvider)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero section
                VStack(spacing: 12) {
                    Text("Looking to break out of\nyour pizza routine?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("QuickPizza has your back!")
                        .font(.headline)
                        .foregroundStyle(AppColors.primary)

                    Text("With just one click, you'll discover new and exciting pizza combinations with just one click!")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 16)

                // Quote
                if !viewModel.quote.isEmpty {
                    Text("\"\(viewModel.quote)\"")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Customize section
                CustomizeSection(
                    restrictions: $viewModel.restrictions,
                    availableTools: viewModel.availableTools
                )

                // Get Recommendation button
                Button {
                    Task { await viewModel.getRecommendation() }
                } label: {
                    HStack(spacing: 8) {
                        Text("🍕")
                        Text("Pizza, Please!")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isLoading)

                // Loading
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding()
                }

                // Error
                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.error)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.error)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.error.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Pizza result
                if let recommendation = viewModel.recommendation {
                    PizzaCard(recommendation: recommendation)

                    RatingButtons(
                        onRate: { stars in
                            Task { await viewModel.ratePizza(stars: stars) }
                        },
                        isSubmitted: viewModel.ratingSubmitted
                    )
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .background(AppColors.background)
        .task {
            await viewModel.start()
        }
    }
}

#Preview {
    HomeView()
}
