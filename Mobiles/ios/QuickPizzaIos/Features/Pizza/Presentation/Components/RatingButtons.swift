import SwiftUI

/// "Love it" / "Pass" rating buttons, shown after a pizza recommendation.
struct RatingButtons: View {
    let onRate: (Int) -> Void
    let isSubmitted: Bool

    var body: some View {
        if isSubmitted {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.success)
                Text("Thanks for rating!")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.success)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .transition(.opacity)
        } else {
            HStack(spacing: 12) {
                Button {
                    onRate(5)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                        Text("Love it!")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    onRate(1)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsdown.fill")
                        Text("Pass")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}
