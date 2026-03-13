package com.grafana.quickpizza.core.o11y

import android.app.Application
import android.util.Log
import com.grafana.quickpizza.core.config.AppConfig
import io.opentelemetry.android.OpenTelemetryRum
import io.opentelemetry.android.agent.OpenTelemetryRumInitializer
import io.opentelemetry.api.OpenTelemetry
import io.opentelemetry.api.common.AttributeKey
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OTelService @Inject constructor(
    private val application: Application,
    private val appConfig: AppConfig,
) {
    private var rum: OpenTelemetryRum? = null

    val openTelemetry: OpenTelemetry
        get() = rum?.openTelemetry ?: OpenTelemetry.noop()

    fun initialize() {
        val endpoint = appConfig.otlpEndpoint
        val authHeader = appConfig.otlpAuthHeader

        if (endpoint.isEmpty()) {
            Log.w(TAG, "OTLP endpoint not configured — running with noop telemetry")
            return
        }

        rum = runCatching {
            OpenTelemetryRumInitializer.initialize(application) {
                httpExport {
                    baseUrl = endpoint
                    if (authHeader.isNotEmpty()) {
                        baseHeaders = mapOf("Authorization" to authHeader)
                    }
                }
                resource {
                    put(AttributeKey.stringKey("service.name"), "quickpizza-android")
                    put(AttributeKey.stringKey("service.namespace"), "quickpizza")
                    put(AttributeKey.stringKey("service.version"), appConfig.appVersion)
                }
            }
        }.onFailure { Log.e(TAG, "OTelService initialization failed", it) }.getOrNull()

        if (rum != null) Log.i(TAG, "OTelService initialized, exporting to $endpoint")
    }

    fun getTracer(instrumentationScope: String = INSTRUMENTATION_SCOPE) =
        openTelemetry.getTracer(instrumentationScope)

    fun getLoggerProvider() = openTelemetry.logsBridge

    companion object {
        private const val TAG = "OTelService"
        const val INSTRUMENTATION_SCOPE = "com.grafana.quickpizza"
    }
}
