package com.grafana.quickpizza.di

import com.grafana.quickpizza.core.api.ApiClient
import com.grafana.quickpizza.core.api.buildBaseOkHttpClient
import com.grafana.quickpizza.core.config.ApplicationScope
import com.grafana.quickpizza.core.config.DebugSettingsRepository
import com.grafana.quickpizza.core.config.RuntimeConfigHolder
import com.grafana.quickpizza.core.o11y.AppEvents
import com.grafana.quickpizza.core.o11y.AppLogger
import com.grafana.quickpizza.core.o11y.AppTracer
import com.grafana.quickpizza.core.o11y.CompositeLogger
import com.grafana.quickpizza.core.o11y.LogcatLogger
import com.grafana.quickpizza.core.o11y.OTelService
import com.grafana.quickpizza.core.o11y.OtelEvents
import com.grafana.quickpizza.core.o11y.OtelLogger
import com.grafana.quickpizza.core.o11y.OtelTracer
import com.grafana.quickpizza.core.storage.TokenStorage
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.opentelemetry.instrumentation.okhttp.v3_0.OkHttpTelemetry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import okhttp3.Call
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    @ApplicationScope
    fun provideApplicationScope(): CoroutineScope = CoroutineScope(SupervisorJob())

    @Provides
    @Singleton
    fun provideOkHttpCallFactory(otelService: OTelService): Call.Factory =
        OkHttpTelemetry.create(otelService.openTelemetry).createCallFactory(buildBaseOkHttpClient())

    @Provides
    @Singleton
    fun provideApiClient(
        callFactory: Call.Factory,
        runtimeConfig: RuntimeConfigHolder,
        debugSettings: DebugSettingsRepository,
        tokenStorage: TokenStorage,
    ): ApiClient = ApiClient(
        callFactory = callFactory,
        baseUrlProvider = { runtimeConfig.current.backendBaseUrl },
        tokenProvider = { tokenStorage.token },
        errorHeadersProvider = { debugSettings.current.errorInjectionHeaders },
    )

    @Provides
    @Singleton
    fun provideAppLogger(otelService: OTelService): AppLogger = CompositeLogger(
        listOf(
            LogcatLogger(),
            OtelLogger(otelService.getLoggerProvider()),
        ),
    )

    @Provides
    @Singleton
    fun provideAppTracer(otelService: OTelService): AppTracer =
        OtelTracer(otelService.getTracer())

    @Provides
    @Singleton
    fun provideAppEvents(otelService: OTelService): AppEvents =
        OtelEvents(otelService.getLoggerProvider())
}
