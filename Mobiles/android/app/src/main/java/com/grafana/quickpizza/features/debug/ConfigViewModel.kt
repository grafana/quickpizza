package com.grafana.quickpizza.features.debug

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.grafana.quickpizza.core.config.AppConfig
import com.grafana.quickpizza.core.config.DebugSettings
import com.grafana.quickpizza.core.config.DebugSettingsRepository
import com.grafana.quickpizza.core.config.RuntimeConfigHolder
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ConfigUiState(
    val backendInUse: String,
    val otlpInUse: String,
    val otlpInstanceIdInUse: String,
    val otlpApiKeyInUse: String,
    val defaultBackend: String,
    val defaultOtlp: String,
    val defaultOtlpInstanceId: String,
    val defaultOtlpApiKey: String,
    val savedBackendOverride: String?,
    val savedOtlpOverride: String?,
    val savedOtlpInstanceIdOverride: String?,
    val savedOtlpApiKeyOverride: String?,
    val saving: Boolean = false,
    val statusMessage: String? = null,
    val restartBanner: RestartBannerState = RestartBannerState.Hidden,
)

@HiltViewModel
class ConfigViewModel @Inject constructor(
    private val debugSettings: DebugSettingsRepository,
    private val runtimeConfig: RuntimeConfigHolder,
    private val appConfig: AppConfig,
) : ViewModel() {

    private val _state = MutableStateFlow(buildState(debugSettings.current))
    val state: StateFlow<ConfigUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            debugSettings.state.collect { settings ->
                _state.update { current ->
                    buildState(settings).copy(
                        saving = current.saving,
                        statusMessage = current.statusMessage,
                    )
                }
            }
        }
    }

    fun save(
        backendUrl: String,
        otlpEndpoint: String,
        otlpInstanceId: String,
        otlpApiKey: String,
    ) {
        viewModelScope.launch {
            _state.update { it.copy(saving = true, statusMessage = null) }
            debugSettings.saveConfigOverrides(
                backendUrl = backendUrl.ifBlank { null },
                otlpEndpoint = otlpEndpoint.ifBlank { null },
                otlpInstanceId = otlpInstanceId.ifBlank { null },
                otlpApiKey = otlpApiKey.ifBlank { null },
            )
            _state.update {
                it.copy(
                    saving = false,
                    statusMessage = "Saved. Kill and relaunch the app for changes to take effect.",
                )
            }
        }
    }

    fun clear() {
        viewModelScope.launch {
            _state.update { it.copy(saving = true, statusMessage = null) }
            debugSettings.saveConfigOverrides(
                backendUrl = null,
                otlpEndpoint = null,
                otlpInstanceId = null,
                otlpApiKey = null,
            )
            _state.update {
                it.copy(
                    saving = false,
                    statusMessage = "Overrides cleared. Kill and relaunch to use defaults.",
                )
            }
        }
    }

    private fun buildState(settings: DebugSettings): ConfigUiState {
        val current = runtimeConfig.current
        return ConfigUiState(
            backendInUse = current.backendBaseUrl,
            otlpInUse = current.otlpEndpoint,
            otlpInstanceIdInUse = current.otlpInstanceId,
            otlpApiKeyInUse = current.otlpApiKey,
            defaultBackend = appConfig.baseUrl,
            defaultOtlp = appConfig.otlpEndpoint,
            defaultOtlpInstanceId = appConfig.otlpInstanceId,
            defaultOtlpApiKey = appConfig.otlpApiKey,
            savedBackendOverride = settings.backendUrlOverride,
            savedOtlpOverride = settings.otlpEndpointOverride,
            savedOtlpInstanceIdOverride = settings.otlpInstanceIdOverride,
            savedOtlpApiKeyOverride = settings.otlpApiKeyOverride,
            restartBanner = computeRestartBanner(settings, current),
        )
    }
}
