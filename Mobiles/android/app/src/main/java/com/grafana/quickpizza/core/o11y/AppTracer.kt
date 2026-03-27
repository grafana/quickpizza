package com.grafana.quickpizza.core.o11y

import io.opentelemetry.api.trace.Span
import io.opentelemetry.api.trace.SpanKind
import io.opentelemetry.api.trace.StatusCode
import io.opentelemetry.api.trace.Tracer
import io.opentelemetry.extension.kotlin.asContextElement
import kotlinx.coroutines.withContext

// ---------------------------------------------------------------------------
// Protocol
// ---------------------------------------------------------------------------

interface AppTracer {
    fun startSpan(name: String, kind: SpanKind = SpanKind.INTERNAL): AppSpan

    suspend fun <T> withSpan(
        name: String,
        kind: SpanKind = SpanKind.INTERNAL,
        block: suspend (AppSpan) -> T,
    ): T
}

interface AppSpan {
    fun setAttribute(key: String, value: String)
    fun setAttribute(key: String, value: Long)
    fun setAttribute(key: String, value: Double)
    fun setAttribute(key: String, value: Boolean)
    fun setError(description: String)
    fun recordException(error: Throwable)
    fun end()
}

// ---------------------------------------------------------------------------
// OtelTracer
// ---------------------------------------------------------------------------

class OtelTracer(otelTracer: Tracer) : AppTracer {
    private val tracer: Tracer = otelTracer

    override fun startSpan(name: String, kind: SpanKind): AppSpan {
        val span = tracer.spanBuilder(name)
            .setSpanKind(kind)
            .startSpan()
        return OtelSpan(span)
    }

    override suspend fun <T> withSpan(
        name: String,
        kind: SpanKind,
        block: suspend (AppSpan) -> T,
    ): T {
        val span = tracer.spanBuilder(name)
            .setSpanKind(kind)
            .startSpan()
        val wrappedSpan = OtelSpan(span)

        // asContextElement() implements ThreadContextElement, which restores the OTel
        // ThreadLocal on every thread the coroutine dispatches to, ensuring nested HTTP
        // spans (auto-instrumented by the OkHttp agent) are correctly parented.
        return withContext(span.asContextElement()) {
            try {
                block(wrappedSpan)
            } catch (e: Exception) {
                wrappedSpan.recordException(e)
                throw e
            } finally {
                wrappedSpan.end()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// OtelSpan
// ---------------------------------------------------------------------------

class OtelSpan(private val span: Span) : AppSpan {
    override fun setAttribute(key: String, value: String) {
        span.setAttribute(key, value)
    }

    override fun setAttribute(key: String, value: Long) {
        span.setAttribute(key, value)
    }

    override fun setAttribute(key: String, value: Double) {
        span.setAttribute(key, value)
    }

    override fun setAttribute(key: String, value: Boolean) {
        span.setAttribute(key, value)
    }

    override fun setError(description: String) {
        span.setStatus(StatusCode.ERROR, description)
    }

    override fun recordException(error: Throwable) {
        span.recordException(error)
        span.setStatus(StatusCode.ERROR, error.message ?: "")
    }

    override fun end() {
        span.end()
    }
}
