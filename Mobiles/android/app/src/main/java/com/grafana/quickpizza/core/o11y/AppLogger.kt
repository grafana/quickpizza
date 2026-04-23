package com.grafana.quickpizza.core.o11y

import android.util.Log
import io.opentelemetry.api.common.AttributeKey
import io.opentelemetry.api.logs.Logger
import io.opentelemetry.api.logs.LoggerProvider
import io.opentelemetry.api.logs.Severity

// ---------------------------------------------------------------------------
// Protocol
// ---------------------------------------------------------------------------

/**
 * Application logging facade.
 *
 * Two distinct error-level entry points:
 *
 *  - [error] — a "soft" application error with no `Throwable` involved.
 *    Emitted as a plain ERROR-severity `LogRecord`. Intended to surface in
 *    a logs view, but NOT to count toward exception/crash dashboards.
 *  - [exception] — a caught `Throwable`. Emitted per the OpenTelemetry stable
 *    "Semantic conventions for exceptions in logs"
 *    (https://opentelemetry.io/docs/specs/semconv/exceptions/exceptions-logs/)
 *    with `exception.type`, `exception.message`, `exception.stacktrace`
 *    attributes. Also sets the top-level `EventName` to `"exception"` so
 *    backends can filter exception/crash records on a single field.
 *
 * If you caught a `Throwable`, prefer [exception]. Use [error] only when no
 * throwable is involved.
 */
interface AppLogger {
    fun debug(message: String, attributes: Map<String, String> = emptyMap())
    fun info(message: String, attributes: Map<String, String> = emptyMap())
    fun warning(message: String, attributes: Map<String, String> = emptyMap())
    fun error(message: String, attributes: Map<String, String> = emptyMap())
    fun exception(message: String, error: Throwable, attributes: Map<String, String> = emptyMap())
}

// ---------------------------------------------------------------------------
// CompositeLogger
// ---------------------------------------------------------------------------

class CompositeLogger(private val loggers: List<AppLogger>) : AppLogger {
    override fun debug(message: String, attributes: Map<String, String>) =
        loggers.forEach { it.debug(message, attributes) }

    override fun info(message: String, attributes: Map<String, String>) =
        loggers.forEach { it.info(message, attributes) }

    override fun warning(message: String, attributes: Map<String, String>) =
        loggers.forEach { it.warning(message, attributes) }

    override fun error(message: String, attributes: Map<String, String>) =
        loggers.forEach { it.error(message, attributes) }

    override fun exception(message: String, error: Throwable, attributes: Map<String, String>) =
        loggers.forEach { it.exception(message, error, attributes) }
}

// ---------------------------------------------------------------------------
// LogcatLogger
// ---------------------------------------------------------------------------

class LogcatLogger(private val tag: String = "QuickPizza") : AppLogger {
    override fun debug(message: String, attributes: Map<String, String>) {
        Log.d(tag, message)
    }

    override fun info(message: String, attributes: Map<String, String>) {
        Log.i(tag, message)
    }

    override fun warning(message: String, attributes: Map<String, String>) {
        Log.w(tag, message)
    }

    override fun error(message: String, attributes: Map<String, String>) {
        Log.e(tag, message)
    }

    override fun exception(message: String, error: Throwable, attributes: Map<String, String>) {
        Log.e(tag, message, error)
    }
}

// ---------------------------------------------------------------------------
// OtelLogger
// ---------------------------------------------------------------------------

class OtelLogger(loggerProvider: LoggerProvider) : AppLogger {
    private val logger: Logger = loggerProvider
        .loggerBuilder(OTelService.INSTRUMENTATION_SCOPE)
        .build()

    override fun debug(message: String, attributes: Map<String, String>) {
        emit(message, Severity.DEBUG, attributes)
    }

    override fun info(message: String, attributes: Map<String, String>) {
        emit(message, Severity.INFO, attributes)
    }

    override fun warning(message: String, attributes: Map<String, String>) {
        emit(message, Severity.WARN, attributes)
    }

    override fun error(message: String, attributes: Map<String, String>) {
        emit(message, Severity.ERROR, attributes)
    }

    override fun exception(message: String, error: Throwable, attributes: Map<String, String>) {
        val attrs = attributes.toMutableMap().apply {
            put("exception.type", error.javaClass.name)
            put("exception.message", error.message ?: "")
            put("exception.stacktrace", error.stackTraceToString())
        }
        val builder = logger.logRecordBuilder()
            .setEventName("exception")
            .setBody(message)
            .setSeverity(Severity.ERROR)
        attrs.forEach { (k, v) -> builder.setAttribute(AttributeKey.stringKey(k), v) }
        builder.emit()
    }

    private fun emit(
        message: String,
        severity: Severity,
        attributes: Map<String, String>,
    ) {
        val builder = logger.logRecordBuilder()
            .setBody(message)
            .setSeverity(severity)
        attributes.forEach { (k, v) -> builder.setAttribute(AttributeKey.stringKey(k), v) }
        builder.emit()
    }
}
