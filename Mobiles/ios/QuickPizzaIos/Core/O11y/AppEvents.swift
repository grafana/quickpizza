import Foundation
import OpenTelemetryApi
import SwiftUI
import SwiftiePod

let appEventsProvider = Provider<AppEvents> { pod in
    OtelEvents(otelService: pod.resolve(otelServiceProvider))
}

/// Emit application-defined events (e.g. `pizza.requested`, `debug.test_event`).
///
/// Follows the OpenTelemetry "Semantic conventions for events":
///
///  - An event is a `LogRecord` whose top-level `EventName` field uniquely
///    identifies the event type. We set it via `LogRecordBuilder.setEventName`.
///  - Event names follow the OTel naming guidelines — lowercase,
///    dot-separated, namespaced as `<namespace>.<event>`
///    (e.g. `pizza.requested`, `auth.logged_in`, `debug.test_event`).
///  - Context goes in attributes.
///  - Severity number is set (defaults to INFO).
///  - Body is intentionally left empty: per spec it should only carry a
///    human-readable display message, which we don't have for these events.
protocol AppEvents {
    func trackEvent(_ name: String, attributes: [String: String])
}

extension AppEvents {
    func trackEvent(_ name: String, attributes: [String: String] = [:]) {
        trackEvent(name, attributes: attributes)
    }

    /// Emits a screen view event following OTel semconv `app.screen.*` conventions.
    /// No official event exists yet, so we use `app.screen.view` as the event name
    /// with the registered `app.screen.name` attribute key.
    func trackScreenView(_ screenName: String) {
        trackEvent("app.screen.view", attributes: [
            "app.screen.name": screenName,
        ])
    }
}

final class OtelEvents: AppEvents {
    private let otelLogger: OpenTelemetryApi.Logger

    init(otelService: OTelService) {
        self.otelLogger = otelService.getLogger()
    }

    func trackEvent(_ name: String, attributes: [String: String]) {
        var otelAttributes = attributes.reduce(
            into: [String: OpenTelemetryApi.AttributeValue]()
        ) { result, pair in
            result[pair.key] = .string(pair.value)
        }
        otelAttributes["level"] = .string("INFO")

        let builder = otelLogger
            .logRecordBuilder()
            .setTimestamp(Date())
            .setAttributes(otelAttributes)
            .setSeverity(.info)
        _ = builder.setEventName(name)
        builder.emit()
    }
}

// MARK: - SwiftUI View Modifier

extension View {
    func trackScreenView(_ screenName: String) -> some View {
        let events: AppEvents = pod.resolve(appEventsProvider)
        return onAppear { events.trackScreenView(screenName) }
    }
}
