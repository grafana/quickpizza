import SwiftUI

/// "Love it" / "Pass" rating buttons, shown after a pizza recommendation.
struct RatingButtons: View {
    let onRate: (Int) -> Void
    let isSubmitted: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    onRate(1)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsdown.fill")
                        Text("Pass")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    onRate(5)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                        Text("Love it!")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            
            if isSubmitted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                    Text("Rated!")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.success)
                }
                .transition(.opacity)
            }
        }
    }
}
