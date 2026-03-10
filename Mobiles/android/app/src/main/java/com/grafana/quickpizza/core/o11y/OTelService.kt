package com.grafana.quickpizza.core.o11y

import android.app.Application
import android.util.Log
import com.grafana.quickpizza.core.config.AppConfig
import io.opentelemetry.android.OpenTelemetryRum
import io.opentelemetry.api.OpenTelemetry
import io.opentelemetry.api.common.AttributeKey
import io.opentelemetry.api.common.Attributes
import javax.inject.Inject
import javax.inject.Singleton

// Checking what's available on OpenTelemetryRum at compile time
private val _checkClass: Class<OpenTelemetryRum> = OpenTelemetryRum::class.java

@Singleton
class OTelService @Inject constructor(
    private val application: Application,
    private val appConfig: AppConfig,
) {
    private var rum: OpenTelemetryRum? = null

    val openTelemetry: OpenTelemetry
        get() = rum?.openTelemetry ?: OpenTelemetry.noop()

    fun initialize() {
        // TODO: configure properly once API is resolved
        Log.d(TAG, "OTelService.initialize() - available methods: ${OpenTelemetryRum::class.java.methods.map { it.name }}")
    }

    fun getTracer(instrumentationScope: String = INSTRUMENTATION_SCOPE) =
        openTelemetry.getTracer(instrumentationScope)

    fun getLoggerProvider() = openTelemetry.logsBridge

    companion object {
        private const val TAG = "OTelService"
        const val INSTRUMENTATION_SCOPE = "com.grafana.quickpizza"
    }
}
