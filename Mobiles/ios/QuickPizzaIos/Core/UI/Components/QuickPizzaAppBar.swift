import SwiftUI

/// Shared toolbar content for the QuickPizza app bar.
/// Provides the orange "QuickPizza" title and profile button.
struct QuickPizzaToolbar: ToolbarContent {
    let onProfileTap: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 6) {
                Text("🍕")
                    .font(.title3)
                Text("QuickPizza")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.primary)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onProfileTap) {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    )
            }
        }
    }
}
