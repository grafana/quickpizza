package com.grafana.quickpizza.core.o11y

import android.util.Log
import io.opentelemetry.api.logs.Logger
import io.opentelemetry.api.logs.LoggerProvider
import io.opentelemetry.api.logs.Severity

// ---------------------------------------------------------------------------
// Protocol
// ---------------------------------------------------------------------------

interface AppLogger {
    fun debug(message: String, attributes: Map<String, String> = emptyMap())
    fun info(message: String, attributes: Map<String, String> = emptyMap())
    fun warning(message: String, attributes: Map<String, String> = emptyMap())
    fun error(message: String, error: Throwable? = null, attributes: Map<String, String> = emptyMap())
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

    override fun error(message: String, error: Throwable?, attributes: Map<String, String>) =
        loggers.forEach { it.error(message, error, attributes) }

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

    override fun error(message: String, error: Throwable?, attributes: Map<String, String>) {
        Log.e(tag, message, error)
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

    override fun error(message: String, error: Throwable?, attributes: Map<String, String>) {
        val attrs = attributes.toMutableMap()
        if (error != null) {
            attrs["error.type"] = error.javaClass.name
            attrs["error.message"] = error.message ?: ""
        }
        val fullMessage = if (error != null) "$message: ${error.message}" else message
        emit(fullMessage, Severity.ERROR, attrs)
    }

    override fun exception(message: String, error: Throwable, attributes: Map<String, String>) {
        val attrs = attributes.toMutableMap().apply {
            put("exception.type", error.javaClass.name)
            put("exception.message", error.message ?: "")
            put("exception.stacktrace", error.stackTraceToString())
            put("error.type", error.javaClass.name)
        }
        emit(message, Severity.ERROR, attrs, eventName = "exception")
    }

    private fun emit(
        message: String,
        severity: Severity,
        attributes: Map<String, String>,
        eventName: String? = null,
    ) {
        val builder = logger.logRecordBuilder()
            .setBody(message)
            .setSeverity(severity)
        attributes.forEach { (k, v) -> builder.setAttribute(io.opentelemetry.api.common.AttributeKey.stringKey(k), v) }
        builder.setAttribute(io.opentelemetry.api.common.AttributeKey.stringKey("level"), severity.name.lowercase())
        if (eventName != null) {
            builder.setAttribute(io.opentelemetry.api.common.AttributeKey.stringKey("event.name"), eventName)
        }
        builder.emit()
    }
}
