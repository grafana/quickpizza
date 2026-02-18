import SwiftUI
import SwiftiePod

struct AboutView: View {
    private let appVersion: String = pod.resolve(appVersionProvider)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero section
                VStack(spacing: 16) {
                    // Pizza icon
                    Text("🍕")
                        .font(.system(size: 72))
                        .padding(.top, 16)

                    Text("About QuickPizza")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Discover new and exciting pizza\ncombinations with just one click!")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Links section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Links")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    ForEach(LinkItem.links) { link in
                        Link(destination: link.url) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: link.icon)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(AppColors.textPrimary)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(link.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(12)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                        }
                    }
                }

                // About section
                VStack(alignment: .leading, spacing: 16) {
                    Text("About This Demo")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("QuickPizza is a demo application showcasing Grafana's mobile observability capabilities using OpenTelemetry.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Features demonstrated:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.success)
                                .font(.subheadline)
                            Text(feature)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
                .cardStyle()

                // Footer
                VStack(spacing: 4) {
                    Text("Made with love by QuickPizza Labs")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.6))

                    HStack(spacing: 4) {
                        Text("🟠")
                            .font(.caption2)
                        Text("Powered by OpenTelemetry Swift")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                    }

                    Text("Version \(appVersion)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.primary.opacity(0.6))
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .background(AppColors.background)
    }

    private var features: [String] {
        [
            "Real User Monitoring (RUM)",
            "Error tracking & crash reporting",
            "Custom events & metrics",
            "Distributed tracing",
            "Performance vitals",
        ]
    }
}

#Preview {
    AboutView()
}
