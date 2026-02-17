import SwiftUI

/// Shared toolbar content for the QuickPizza app bar.
/// Provides the orange "QuickPizza" title and profile button.
struct QuickPizzaToolbar: ToolbarContent {
    let onProfileTap: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                Text("🍕")
                    .font(.title2)
                Text("QuickPizza")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.primary)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onProfileTap) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
