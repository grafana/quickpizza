package com.grafana.quickpizza.core.o11y

import io.opentelemetry.api.common.AttributeKey
import io.opentelemetry.api.logs.Logger
import io.opentelemetry.api.logs.LoggerProvider
import io.opentelemetry.api.logs.Severity

/**
 * Emit application-defined events (e.g. `pizza.requested`, `debug.test_event`).
 *
 * Follows the OpenTelemetry "Semantic conventions for events"
 * (https://opentelemetry.io/docs/specs/semconv/general/events/):
 *
 *  - An event is a `LogRecord` whose top-level `EventName` field uniquely
 *    identifies the event type. We set it via `LogRecordBuilder.setEventName`.
 *    The previously-used `event.name` attribute is deprecated in favor of this
 *    top-level field.
 *  - Event names follow the OTel naming guidelines
 *    (https://opentelemetry.io/docs/specs/semconv/general/naming/) — lowercase,
 *    dot-separated, namespaced as `<namespace>.<event>`
 *    (e.g. `pizza.requested`, `auth.logged_in`, `debug.test_event`).
 *  - Context goes in attributes.
 *  - Severity number is set (defaults to INFO).
 *  - Body is intentionally left empty: per spec it should only carry a
 *    human-readable display message, which we don't have for these events.
 */
interface AppEvents {
    fun trackEvent(name: String, attributes: Map<String, String> = emptyMap())
}

class OtelEvents(loggerProvider: LoggerProvider) : AppEvents {
    private val logger: Logger = loggerProvider
        .loggerBuilder(OTelService.INSTRUMENTATION_SCOPE)
        .build()

    override fun trackEvent(name: String, attributes: Map<String, String>) {
        val builder = logger.logRecordBuilder()
            .setEventName(name)
            .setSeverity(Severity.INFO)
        attributes.forEach { (k, v) -> builder.setAttribute(AttributeKey.stringKey(k), v) }
        builder.emit()
    }
}
