package com.grafana.quickpizza.core.o11y

import io.opentelemetry.api.trace.Span
import io.opentelemetry.api.trace.SpanKind
import io.opentelemetry.api.trace.StatusCode
import io.opentelemetry.api.trace.Tracer
import io.opentelemetry.context.Context
import kotlinx.coroutines.withContext
import kotlin.coroutines.CoroutineContext

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

        // Make the span active in OTel context so nested HTTP calls are child spans
        val scope = span.makeCurrent()
        return try {
            withContext(OtelContextElement(Context.current())) {
                try {
                    block(wrappedSpan)
                } catch (e: Exception) {
                    wrappedSpan.recordException(e)
                    throw e
                }
            }
        } finally {
            scope.close()
            wrappedSpan.end()
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

// ---------------------------------------------------------------------------
// Coroutine context element for OTel context propagation
// ---------------------------------------------------------------------------

class OtelContextElement(private val otelContext: Context) : CoroutineContext.Element {
    override val key: CoroutineContext.Key<*> = Key

    companion object Key : CoroutineContext.Key<OtelContextElement>
}
