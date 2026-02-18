import SwiftUI

/// QuickPizza color palette — warm orange/cream inspired by the Flutter app.
enum AppColors {
    /// Primary orange for buttons, accents, and highlights.
    static let primary = Color(red: 0.95, green: 0.55, blue: 0.16) // ~#F28C28
    /// Darker orange for text on light backgrounds.
    static let primaryDark = Color(red: 0.85, green: 0.42, blue: 0.08)
    /// Light orange for subtle highlights.
    static let primaryLight = Color(red: 1.0, green: 0.87, blue: 0.68) // ~#FFDE9E
    /// Warm cream background.
    static let background = Color(red: 1.0, green: 0.97, blue: 0.94) // ~#FFF8F0
    /// White card surface.
    static let cardBackground = Color.white
    /// Dark text color.
    static let textPrimary = Color(red: 0.2, green: 0.2, blue: 0.2)
    /// Secondary/muted text.
    static let textSecondary = Color(red: 0.5, green: 0.5, blue: 0.5)
    /// Error red.
    static let error = Color(red: 0.85, green: 0.2, blue: 0.2)
    /// Success green for checkmarks.
    static let success = Color(red: 0.2, green: 0.7, blue: 0.3)
    /// Star gold for ratings.
    static let starGold = Color(red: 1.0, green: 0.75, blue: 0.0)
}

/// Shared card styling modifier.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

/// Primary button style matching the Flutter app's orange buttons.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                configuration.isPressed
                    ? AppColors.primaryDark
                    : AppColors.primary
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary / outlined button style.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Apply the QuickPizza card style.
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
