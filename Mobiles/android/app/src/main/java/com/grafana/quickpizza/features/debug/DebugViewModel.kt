package com.grafana.quickpizza.features.debug

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.grafana.quickpizza.core.config.DebugSettings
import com.grafana.quickpizza.core.config.DebugSettingsRepository
import com.grafana.quickpizza.core.config.RuntimeConfig
import com.grafana.quickpizza.core.config.RuntimeConfigHolder
import com.grafana.quickpizza.core.o11y.AppEvents
import com.grafana.quickpizza.core.o11y.AppLogger
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

private val DEBUG_TAB_CONTEXT = mapOf("debug.source" to "debug_tab")

data class DebugUiState(
    val settings: DebugSettings = DebugSettings(),
    val restartBanner: RestartBannerState = RestartBannerState.Hidden,
    val lastActionMessage: String? = null,
)

sealed interface RestartBannerState {
    data object Hidden : RestartBannerState
    data class Visible(val changedLabel: String) : RestartBannerState
}

/**
 * Computes whether the persisted overrides differ from the URLs/credentials
 * actually in use this session. Shared by [DebugViewModel] and
 * [ConfigViewModel] so the banner is consistent on both screens.
 */
fun computeRestartBanner(
    settings: DebugSettings,
    runtime: RuntimeConfig,
): RestartBannerState {
    val savedBackend = settings.backendUrlOverride ?: runtime.backendBaseUrl
    val savedOtlp = settings.otlpEndpointOverride ?: runtime.otlpEndpoint
    val savedInstanceId = settings.otlpInstanceIdOverride ?: runtime.otlpInstanceId
    val savedApiKey = settings.otlpApiKeyOverride ?: runtime.otlpApiKey
    val savedDiskBufferingEnabled = !settings.disableDiskBuffering
    val changedFields = listOfNotNull(
        "Backend URL".takeIf { savedBackend != runtime.backendBaseUrl },
        "OTLP endpoint".takeIf { savedOtlp != runtime.otlpEndpoint },
        "OTLP instance ID".takeIf { savedInstanceId != runtime.otlpInstanceId },
        "OTLP API key".takeIf { savedApiKey != runtime.otlpApiKey },
        "Disk buffering".takeIf { savedDiskBufferingEnabled != runtime.diskBufferingEnabled },
    )
    return if (changedFields.isEmpty()) {
        RestartBannerState.Hidden
    } else {
        RestartBannerState.Visible(changedFields.joinToString(", "))
    }
}

@HiltViewModel
class DebugViewModel @Inject constructor(
    private val debugSettings: DebugSettingsRepository,
    private val runtimeConfig: RuntimeConfigHolder,
    private val logger: AppLogger,
    private val events: AppEvents,
) : ViewModel() {

    private val _state = MutableStateFlow(
        DebugUiState(
            settings = debugSettings.current,
            restartBanner = computeRestartBanner(debugSettings.current, runtimeConfig.current),
        ),
    )
    val state: StateFlow<DebugUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            debugSettings.state.collect { settings ->
                _state.update {
                    it.copy(
                        settings = settings,
                        restartBanner = computeRestartBanner(settings, runtimeConfig.current),
                    )
                }
            }
        }
    }

    // ---------------------------------------------------------------------
    // Toggles (persisted)
    // ---------------------------------------------------------------------

    fun setSlowRecommendations(value: Boolean) = launch { debugSettings.setSlowRecommendations(value) }
    fun setSlowIngredients(value: Boolean) = launch { debugSettings.setSlowIngredients(value) }
    fun setErrorOnRecommendations(value: Boolean) = launch { debugSettings.setErrorOnRecommendations(value) }
    fun setErrorOnIngredients(value: Boolean) = launch { debugSettings.setErrorOnIngredients(value) }
    fun setUseV2PizzaSchema(value: Boolean) = launch { debugSettings.setUseV2PizzaSchema(value) }
    fun setSkipAuthDepInTools(value: Boolean) = launch { debugSettings.setSkipAuthDepInTools(value) }
    fun setDisableDiskBuffering(value: Boolean) = launch { debugSettings.setDisableDiskBuffering(value) }

    fun resetAll() = launch {
        debugSettings.resetAll()
        showAction("All debug settings reset")
    }

    // ---------------------------------------------------------------------
    // Quick Signals
    // ---------------------------------------------------------------------

    fun sendDebugLog() {
        logger.debug(
            "Test debug log from Debug tab",
            DEBUG_TAB_CONTEXT + ("debug.action" to "logger.debug"),
        )
        showAction("Sent debug log")
    }

    fun sendErrorLog() {
        logger.error(
            "Test error log from Debug tab",
            attributes = DEBUG_TAB_CONTEXT + ("debug.action" to "logger.error"),
        )
        showAction("Sent error log")
    }

    fun sendCustomEvent() {
        events.trackEvent(
            "debug.test_event",
            DEBUG_TAB_CONTEXT + ("debug.action" to "events.trackEvent"),
        )
        showAction("Sent custom event")
    }

    // ---------------------------------------------------------------------
    // Diagnostics
    // ---------------------------------------------------------------------

    fun logTestException() {
        try {
            throw RuntimeException("Test exception from Debug tab")
        } catch (e: Exception) {
            logger.exception(
                "Test exception triggered by user",
                e,
                DEBUG_TAB_CONTEXT + ("debug.action" to "logger.exception"),
            )
        }
        showAction("Sent handled exception")
    }

    fun triggerAnr() {
        // Block the main thread long enough to exceed Android's 5s ANR threshold.
        // Caller invokes from main thread; intentionally not dispatched off it.
        Thread.sleep(6000)
    }

    /**
     * Throws an unhandled exception. The OTel-Android `CrashReporter` instrumentation
     * catches this via `Thread.UncaughtExceptionHandler`, persists it to disk, and
     * the exporter delivers it on the next app launch. The OS then terminates the app.
     */
    fun triggerCrashRuntimeException() {
        throw RuntimeException("Deliberate crash from QuickPizza debug tab")
    }

    /**
     * Triggers a [NullPointerException] via Kotlin's `!!` operator. Same delivery
     * path as [triggerCrashRuntimeException] but mirrors a real-world null-deref bug.
     */
    fun triggerCrashNullPointer() {
        val nothing: String? = null
        nothing!!.length
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    fun clearLastAction() {
        _state.update { it.copy(lastActionMessage = null) }
    }

    private fun showAction(message: String) {
        _state.update { it.copy(lastActionMessage = message) }
    }

    private fun launch(block: suspend () -> Unit) {
        viewModelScope.launch { block() }
    }
}
