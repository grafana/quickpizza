import Foundation
import OpenTelemetrySdk
import OSLog
import OpenTelemetryApi

/// Lightweight span exporter that logs a one-liner per span via `os.Logger`,
/// making spans visible in `log stream` (and the Cursor terminal) alongside app logs.
final class OSLogSpanExporter: SpanExporter {
    private let logger: os.Logger

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.grafana.QuickPizzaIos",
         category: String = "spans") {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        for span in spans {
            let ms = span.endTime.timeIntervalSince(span.startTime) * 1000
            let duration = ms >= 1000
                ? String(format: "%.1fs", ms / 1000)
                : String(format: "%.0fms", ms)

            let status: String
            switch span.status {
            case .error(let desc):
                status = " ERROR: \(desc)"
            default:
                status = ""
            }

            let kind = span.kind.rawValue.uppercased()
            logger.debug("[span] \(kind) \(span.name) \(duration)\(status)")
        }
        return .success
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode { .success }
    func shutdown(explicitTimeout: TimeInterval?) {}
}
