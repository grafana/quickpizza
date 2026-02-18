import SwiftUI
import SwiftiePod

struct ProfileView: View {
    @State private var viewModel = pod.resolve(profileViewModelProvider)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // User card
                    VStack(spacing: 12) {
                        Circle()
                            .fill(AppColors.primaryLight)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(AppColors.primary)
                            )

                        Text(viewModel.username)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(viewModel.pizzaCount) pizzas rated")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .cardStyle()

                    // Ratings section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(AppColors.starGold)
                            Text("Your Ratings")
                                .font(.headline)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if viewModel.ratings.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.title)
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                                Text("No ratings yet")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppColors.textSecondary)
                                Text("Rate some pizzas to see them here!")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(viewModel.ratings) { rating in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pizza #\(rating.pizzaId)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(AppColors.textPrimary)
                                    }
                                    Spacer()
                                    HStack(spacing: 2) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: star <= rating.stars ? "star.fill" : "star")
                                                .font(.caption)
                                                .foregroundStyle(
                                                    star <= rating.stars
                                                        ? AppColors.starGold
                                                        : AppColors.textSecondary.opacity(0.3)
                                                )
                                        }
                                    }
                                    if rating.stars >= 4 {
                                        Image(systemName: "heart.fill")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.error)
                                    } else {
                                        Image(systemName: "hand.thumbsdown.fill")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                                .padding(.vertical, 4)

                                if rating.id != viewModel.ratings.last?.id {
                                    Divider()
                                }
                            }

                            // Clear ratings
                            Button {
                                Task { await viewModel.clearRatings() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Clear All Ratings")
                                }
                                .font(.subheadline)
                                .foregroundStyle(AppColors.error)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                        }
                    }
                    .cardStyle()

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppColors.error)
                            .padding(.horizontal)
                    }

                    // Sign out
                    Button {
                        viewModel.signOut()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .background(AppColors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .task {
                await viewModel.start()
            }
            .onChange(of: viewModel.didLogout) { _, loggedOut in
                if loggedOut { dismiss() }
            }
        }
    }
}

#Preview {
    ProfileView()
}
