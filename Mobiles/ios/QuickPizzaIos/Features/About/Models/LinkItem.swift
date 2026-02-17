import Foundation

struct LinkItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let url: URL

    static let links: [LinkItem] = [
        LinkItem(
            title: "OpenTelemetry Swift SDK",
            subtitle: "View source code and contribute",
            icon: "chevron.left.forwardslash.chevron.right",
            url: URL(string: "https://github.com/open-telemetry/opentelemetry-swift")!
        ),
    ]
}
