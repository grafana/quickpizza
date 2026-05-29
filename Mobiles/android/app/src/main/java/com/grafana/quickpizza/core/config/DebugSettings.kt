package com.grafana.quickpizza.core.config

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.grafana.quickpizza.core.storage.SecureStringStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Snapshot of all values persisted by [DebugSettingsRepository].
 *
 * URL overrides are nullable — `null` means "no override, use the build-time default".
 * Boolean toggles default to `false`.
 */
data class DebugSettings(
    val backendUrlOverride: String? = null,
    val otlpEndpointOverride: String? = null,
    val otlpInstanceIdOverride: String? = null,
    val otlpApiKeyOverride: String? = null,
    val errorOnRecommendations: Boolean = false,
    val errorOnIngredients: Boolean = false,
    val slowRecommendations: Boolean = false,
    val slowIngredients: Boolean = false,
    val useV2PizzaSchema: Boolean = false,
    val skipAuthDepInTools: Boolean = false,
    /**
     * When `true`, the OTel-Android SDK is initialized with `diskBuffering { enabled = false }`,
     * bypassing the on-device file queue and exporting via OTLP directly. Cuts end-to-end
     * latency from ~30–45s to ~1–6s — useful for live demos where you want to see signals
     * land in Grafana right after an action. Read once at app startup; toggling requires
     * a restart.
     */
    val disableDiskBuffering: Boolean = false,
) {
    val hasActiveOverrides: Boolean
        get() = backendUrlOverride != null ||
            otlpEndpointOverride != null ||
            otlpInstanceIdOverride != null ||
            otlpApiKeyOverride != null ||
            errorOnRecommendations ||
            errorOnIngredients ||
            slowRecommendations ||
            slowIngredients ||
            useV2PizzaSchema ||
            skipAuthDepInTools ||
            disableDiskBuffering

    /**
     * Backend expects:
     *  * `x-error-*` headers — value is the error message (any non-empty string)
     *  * `x-delay-*` headers — value is a Go duration string (e.g. `3s`, `500ms`)
     *
     * Delay values are tuned so both toggles produce ~3s of user-visible
     * slowness. `record-recommendation` is called once per `POST /api/pizza`,
     * so 3s → ~3s. `get-ingredients` is called four times per request
     * (oil, tomato, mozzarella, topping), so 750ms → ~3s total.
     */
    val errorInjectionHeaders: Map<String, String>
        get() = buildMap {
            if (errorOnRecommendations) put("x-error-record-recommendation", "simulated recommendation service failure")
            if (errorOnIngredients) put("x-error-get-ingredients", "simulated ingredient lookup failure")
            if (slowRecommendations) put("x-delay-record-recommendation", "3s")
            if (slowIngredients) put("x-delay-get-ingredients", "750ms")
        }
}

private const val SECURE_OTLP_API_KEY = "debug_otlp_api_key"

private val Context.debugSettingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "debug_settings")

private object DebugSettingsKeys {
    val backendUrl = stringPreferencesKey("debug_backend_url")
    val otlpEndpoint = stringPreferencesKey("debug_otlp_endpoint")
    val otlpInstanceId = stringPreferencesKey("debug_otlp_instance_id")
    val errorRecommendations = booleanPreferencesKey("debug_error_recommendations")
    val errorIngredients = booleanPreferencesKey("debug_error_ingredients")
    val slowRecommendations = booleanPreferencesKey("debug_slow_recommendations")
    val slowIngredients = booleanPreferencesKey("debug_slow_ingredients")
    val useV2PizzaSchema = booleanPreferencesKey("debug_use_v2_pizza_schema")
    val skipAuthDepInTools = booleanPreferencesKey("debug_skip_auth_dep_in_tools")
    val disableDiskBuffering = booleanPreferencesKey("debug_disable_disk_buffering")
}

@Singleton
class DebugSettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    @ApplicationScope private val applicationScope: CoroutineScope,
) {
    private val dataStore: DataStore<Preferences> = context.debugSettingsDataStore
    private val secureStore = SecureStringStore(context, "quickpizza_debug_secure")

    val flow: Flow<DebugSettings> = dataStore.data.map { it.toSettings() }

    private val _state: MutableStateFlow<DebugSettings> = MutableStateFlow(DebugSettings())
    val state: StateFlow<DebugSettings> = _state.asStateFlow()
    val current: DebugSettings get() = _state.value

    init {
        runBlocking {
            _state.value = snapshot()
        }
        applicationScope.launch {
            flow.collect { _state.value = it }
        }
    }

    /**
     * Synchronous snapshot. Used at app bootstrap (before coroutines are practical)
     * to seed [com.grafana.quickpizza.core.config.RuntimeConfig]. Blocks the calling
     * thread until DataStore returns the first emission.
     */
    suspend fun snapshot(): DebugSettings = dataStore.data.first().toSettings()

    suspend fun setBackendUrlOverride(value: String?) = updateString(DebugSettingsKeys.backendUrl, value)
    suspend fun setOtlpEndpointOverride(value: String?) = updateString(DebugSettingsKeys.otlpEndpoint, value)
    suspend fun setOtlpInstanceIdOverride(value: String?) = updateString(DebugSettingsKeys.otlpInstanceId, value)
    suspend fun setOtlpApiKeyOverride(value: String?) {
        val normalized = normalize(value)
        secureStore.setString(SECURE_OTLP_API_KEY, normalized)
        _state.value = _state.value.copy(otlpApiKeyOverride = normalized)
    }
    suspend fun setErrorOnRecommendations(value: Boolean) = updateBoolean(DebugSettingsKeys.errorRecommendations, value)
    suspend fun setErrorOnIngredients(value: Boolean) = updateBoolean(DebugSettingsKeys.errorIngredients, value)
    suspend fun setSlowRecommendations(value: Boolean) = updateBoolean(DebugSettingsKeys.slowRecommendations, value)
    suspend fun setSlowIngredients(value: Boolean) = updateBoolean(DebugSettingsKeys.slowIngredients, value)
    suspend fun setUseV2PizzaSchema(value: Boolean) = updateBoolean(DebugSettingsKeys.useV2PizzaSchema, value)
    suspend fun setSkipAuthDepInTools(value: Boolean) = updateBoolean(DebugSettingsKeys.skipAuthDepInTools, value)
    suspend fun setDisableDiskBuffering(value: Boolean) = updateBoolean(DebugSettingsKeys.disableDiskBuffering, value)

    /**
     * Persist all URL + OTLP credential overrides atomically. Empty / blank values
     * clear the corresponding override.
     */
    suspend fun saveConfigOverrides(
        backendUrl: String?,
        otlpEndpoint: String?,
        otlpInstanceId: String?,
        otlpApiKey: String?,
    ) {
        val normalizedBackend = normalize(backendUrl)
        val normalizedOtlp = normalize(otlpEndpoint)
        val normalizedInstanceId = normalize(otlpInstanceId)
        val normalizedApiKey = normalize(otlpApiKey)
        dataStore.edit { prefs ->
            if (normalizedBackend != null) prefs[DebugSettingsKeys.backendUrl] = normalizedBackend
            else prefs.remove(DebugSettingsKeys.backendUrl)
            if (normalizedOtlp != null) prefs[DebugSettingsKeys.otlpEndpoint] = normalizedOtlp
            else prefs.remove(DebugSettingsKeys.otlpEndpoint)
            if (normalizedInstanceId != null) prefs[DebugSettingsKeys.otlpInstanceId] = normalizedInstanceId
            else prefs.remove(DebugSettingsKeys.otlpInstanceId)
        }
        secureStore.setString(SECURE_OTLP_API_KEY, normalizedApiKey)
        _state.value = _state.value.copy(
            backendUrlOverride = normalizedBackend,
            otlpEndpointOverride = normalizedOtlp,
            otlpInstanceIdOverride = normalizedInstanceId,
            otlpApiKeyOverride = normalizedApiKey,
        )
    }

    suspend fun resetAll() {
        dataStore.edit { it.clear() }
        secureStore.setString(SECURE_OTLP_API_KEY, null)
        _state.value = snapshot()
    }

    private suspend fun updateString(key: Preferences.Key<String>, value: String?) {
        val normalized = normalize(value)
        dataStore.edit { prefs ->
            if (normalized != null) prefs[key] = normalized else prefs.remove(key)
        }
    }

    private suspend fun updateBoolean(key: Preferences.Key<Boolean>, value: Boolean) {
        dataStore.edit { it[key] = value }
    }

    private fun normalize(value: String?): String? {
        val trimmed = value?.trim()?.trimEnd('/')
        return if (trimmed.isNullOrEmpty()) null else trimmed
    }

    private fun Preferences.toSettings(): DebugSettings = DebugSettings(
        backendUrlOverride = this[DebugSettingsKeys.backendUrl],
        otlpEndpointOverride = this[DebugSettingsKeys.otlpEndpoint],
        otlpInstanceIdOverride = this[DebugSettingsKeys.otlpInstanceId],
        otlpApiKeyOverride = secureStore.getString(SECURE_OTLP_API_KEY),
        errorOnRecommendations = this[DebugSettingsKeys.errorRecommendations] ?: false,
        errorOnIngredients = this[DebugSettingsKeys.errorIngredients] ?: false,
        slowRecommendations = this[DebugSettingsKeys.slowRecommendations] ?: false,
        slowIngredients = this[DebugSettingsKeys.slowIngredients] ?: false,
        useV2PizzaSchema = this[DebugSettingsKeys.useV2PizzaSchema] ?: false,
        skipAuthDepInTools = this[DebugSettingsKeys.skipAuthDepInTools] ?: false,
        disableDiskBuffering = this[DebugSettingsKeys.disableDiskBuffering] ?: false,
    )
}
