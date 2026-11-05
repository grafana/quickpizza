package com.example.otelandroidsample

import android.app.Application
import android.util.Log
import io.opentelemetry.android.OpenTelemetryRum
import io.opentelemetry.android.agent.OpenTelemetryRumInitializer
import io.opentelemetry.api.OpenTelemetry
import io.opentelemetry.api.common.AttributeKey
import io.opentelemetry.api.common.Attributes
import io.opentelemetry.api.common.AttributesBuilder
import io.opentelemetry.api.logs.Logger
import io.opentelemetry.api.logs.Severity
import io.opentelemetry.api.trace.Span
import io.opentelemetry.api.trace.StatusCode
import io.opentelemetry.api.trace.Tracer
import io.opentelemetry.context.Context
import io.opentelemetry.instrumentation.api.instrumenter.AttributesExtractor
import io.opentelemetry.instrumentation.okhttp.v3_0.OkHttpTelemetry
import okhttp3.Call
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import kotlin.time.Duration.Companion.hours
import kotlin.time.Duration.Companion.minutes

// 1. Your values

object OTelConfig {
    /**
     * Frontend Observability → your app → Settings → Mobile SDK Config → Android:
     * under "3. Initialize Android Agent", copy the `baseUrl` value (it ends in `/otlp/<app-key>`).
     *
     * The app key in the path identifies the app *and* authorises the request,
     * so no API token or `Authorization` header is needed.
     *
     * Do NOT use the Grafana Cloud OTLP gateway (`otlp-gateway-*.grafana.net`):
     * data sent there lands in Loki/Tempo but never shows up in Frontend Observability.
     */
    const val OTLP_ENDPOINT = "https://faro-collector-<region>.grafana.net/otlp/<app-key>"

    /** Separates production, staging, and so on inside one Frontend Observability app. */
    const val ENVIRONMENT = "development"
}

// 2. Setup

/**
 * Wires OpenTelemetry Android for Grafana Frontend Observability.
 *
 * `OpenTelemetryRumInitializer` is the OpenTelemetry Android agent: one call sets up sessions,
 * exporters, crash and ANR reporting, app start, Activity and Fragment screen views, and
 * slow-frame detection. The settings below are the ones Grafana needs; everything else keeps the
 * agent's defaults.
 */
object OTel {
    private const val TAG = "OTel"
    private const val SCOPE = "otel-android-sample"

    /**
     * The agent's runtime, or null until [start] has run (or if it could not start).
     * Only needed for instrumentations you attach yourself, such as Compose navigation.
     */
    var rum: OpenTelemetryRum? = null
        private set

    /**
     * Call once, from [Application.onCreate], before anything else creates spans or logs.
     * Until then (or if the endpoint is not set) the telemetry helpers below send nothing.
     */
    fun start(application: Application) {
        if (OTelConfig.OTLP_ENDPOINT.contains("<")) {
            Log.w(TAG, "Not started: set OTelConfig.OTLP_ENDPOINT to your /otlp/<app-key> URL")
            return
        }

        rum = runCatching {
            OpenTelemetryRumInitializer.initialize(application) {
                // A. Export. Give the base URL only: the agent appends `/v1/traces` and `/v1/logs`.
                httpExport {
                    baseUrl = OTelConfig.OTLP_ENDPOINT
                }

                // B. Sessions. The agent adds `session.id` to every span and log, which the
                //    endpoint REQUIRES (a batch with one record missing it is rejected).
                //    These values are also the agent's defaults; they are spelled out because
                //    they must match Grafana's session rules:
                //    - 15 min in the background ends a session
                //    - a session lasts at most 4 hours
                //    Every cold start begins a new session (the agent keeps sessions in memory).
                session {
                    backgroundInactivityTimeout = 15.minutes
                    maxLifetime = 4.hours
                }

                // C. Resource — attributes attached to every span and log. The agent already adds
                //    device, OS and app version. We change two things:
                //    - remove `service.name` (the app label). Without this, logs, events and
                //      errors show the label while spans show the registered name. Removed,
                //      Grafana uses the app name you registered in Frontend Observability.
                //    - add `deployment.environment.name`.
                resource {
                    removeIf { it.key == "service.name" }
                    put(AttributeKey.stringKey("deployment.environment.name"), OTelConfig.ENVIRONMENT)
                }

                // D. No metrics: the endpoint accepts them and silently drops them.
                disableMetrics()
            }
        }.onFailure { Log.e(TAG, "OpenTelemetry failed to start", it) }.getOrNull()
    }

    // 3. Use it

    /** The OpenTelemetry API. A no-op until [start] has run. */
    val openTelemetry: OpenTelemetry
        get() = rum?.openTelemetry ?: OpenTelemetry.noop()

    /** Tracer for manual spans. Same API as any OpenTelemetry Java app. */
    val tracer: Tracer
        get() = openTelemetry.getTracer(SCOPE)

    val logger: Logger
        get() = openTelemetry.logsBridge.get(SCOPE)

    /**
     * An OkHttp client that creates a span for every request and adds a W3C `traceparent`
     * header, which links it to your backend traces.
     *
     * Created on first use and then kept, so first use must come after [start]; a client
     * created earlier wraps the no-op API and never records anything.
     */
    val httpClient: Call.Factory by lazy { traced(OkHttpClient()) }

    /**
     * Wraps your own `OkHttpClient` the same way, for example to pass to Retrofit's `callFactory`.
     * Call it after [start]. Not using OkHttp? Delete this, [httpClient], [UrlWithoutQuery] and
     * the `okhttp3` / `OkHttpTelemetry` / `AttributesExtractor` imports.
     */
    fun traced(client: OkHttpClient): Call.Factory =
        OkHttpTelemetry.builder(openTelemetry)
            .addAttributesExtractor(UrlWithoutQuery)
            .build()
            .createCallFactory(client)

    /**
     * The instrumentation records the full request URL as `url.full`, and only redacts a few known
     * secret parameters. This replaces it with the URL minus query, fragment and credentials, so
     * tokens or personal data in a query string never leave the device. It runs after the
     * built-in extractors, so it overwrites their value.
     */
    private object UrlWithoutQuery : AttributesExtractor<Interceptor.Chain, Response> {
        override fun onStart(attributes: AttributesBuilder, parentContext: Context, chain: Interceptor.Chain) {
            val url = chain.request().url.newBuilder().query(null).fragment(null).username("").password("").build()
            attributes.put(AttributeKey.stringKey("url.full"), url.toString())
        }

        override fun onEnd(
            attributes: AttributesBuilder,
            context: Context,
            chain: Interceptor.Chain,
            response: Response?,
            error: Throwable?,
        ) = Unit
    }

    /** A log line. Shows up as a log in Frontend Observability. */
    fun log(message: String, severity: Severity = Severity.INFO, attributes: Attributes = Attributes.empty()) {
        logger.logRecordBuilder()
            .setSeverity(severity)
            .setBody(message)
            .setAllAttributes(attributes)
            .emit()
    }

    /** A log record with an event name. Shows up as an event in Frontend Observability. */
    fun event(name: String, attributes: Attributes = Attributes.empty()) {
        logger.logRecordBuilder()
            .setEventName(name)
            .setAllAttributes(attributes)
            .emit()
    }

    /**
     * An error you caught yourself. Crashes are reported automatically.
     * The `exception.*` attributes are what make it an error in Frontend Observability.
     */
    fun logException(error: Throwable, attributes: Attributes = Attributes.empty()) {
        logger.logRecordBuilder()
            .setEventName("exception")
            .setSeverity(Severity.ERROR)
            .setAllAttributes(attributes)
            .setAttribute(AttributeKey.stringKey("exception.type"), error.javaClass.name)
            .setAttribute(AttributeKey.stringKey("exception.message"), error.message.orEmpty())
            .setAttribute(AttributeKey.stringKey("exception.stacktrace"), error.stackTraceToString())
            .emit()
    }

    /**
     * Runs [block] inside a span. Traced OkHttp calls made inside [block] become its
     * children. A thrown exception is recorded on the span and rethrown.
     *
     * The span is current only on the calling thread, so keep [block] synchronous. Work that
     * hops threads (for example a coroutine launched inside it) does not get this span as parent.
     */
    fun <T> span(name: String, block: (Span) -> T): T {
        val span = tracer.spanBuilder(name).startSpan()
        return try {
            span.makeCurrent().use { block(span) }
        } catch (t: Throwable) {
            span.recordException(t)
            span.setStatus(StatusCode.ERROR)
            throw t
        } finally {
            span.end()
        }
    }

    /** The current session ID, handy for finding this session in Frontend Observability. */
    val sessionId: String?
        get() = rum?.sessionProvider?.getSessionId()
}
