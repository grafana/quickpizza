package com.grafana.quickpizza.core.config

import android.content.Context
import android.util.Base64
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Bootstrap configuration loaded from `app/src/main/res/raw/config.json`.
 *
 * Holds the build-time defaults only — runtime overrides (set by the user
 * through Debug → Config) are applied on top by [RuntimeConfigHolder].
 */
@Singleton
class AppConfig @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val config: ConfigFile by lazy { loadConfig() }

    val otlpEndpoint: String get() = config.otlpEndpoint.trim()
    val otlpInstanceId: String get() = config.otlpInstanceId.trim()
    val otlpApiKey: String get() = config.otlpApiKey.trim()

    /** Matches `defaultConfig.applicationId` in `app/build.gradle.kts`. */
    val applicationId: String get() = context.packageName

    val versionCode: Long
        get() = runCatching {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        }.getOrDefault(0L)

    val versionName: String get() = appVersion

    /** Encoded Android symbols bundle id: `{applicationId}@{versionCode}@{versionName}`. */
    val symbolsBundleId: String get() =
        SymbolsBundleId.format(applicationId, versionCode, versionName)

    val appVersion: String get() = runCatching {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "unknown"
    }.getOrDefault("unknown")

    val baseUrl: String
        get() {
            val url = config.baseUrl.trim()
            return if (url.isNotEmpty()) url else defaultBaseUrl
        }

    // Android emulator uses 10.0.2.2 to reach the host machine's localhost.
    // For physical devices, set BASE_URL in config.json to the host machine's LAN IP.
    private val defaultBaseUrl = "http://10.0.2.2:3333"

    private fun loadConfig(): ConfigFile {
        return try {
            val resourceId = context.resources.getIdentifier("config", "raw", context.packageName)
            if (resourceId == 0) {
                ConfigFile()
            } else {
                val json = context.resources.openRawResource(resourceId)
                    .bufferedReader()
                    .use { it.readText() }
                Gson().fromJson(json, ConfigFile::class.java) ?: ConfigFile()
            }
        } catch (e: Exception) {
            ConfigFile()
        }
    }

    private data class ConfigFile(
        @SerializedName("OTLP_ENDPOINT") val otlpEndpoint: String = "",
        @SerializedName("OTLP_INSTANCE_ID") val otlpInstanceId: String = "",
        @SerializedName("OTLP_API_KEY") val otlpApiKey: String = "",
        @SerializedName("BASE_URL") val baseUrl: String = "",
    )
}

/**
 * Builds a Grafana Cloud OTLP Gateway `Authorization` header value:
 * `Basic base64("<instanceId>:<apiKey>")`.
 *
 * Returns `null` when either credential is missing — the OTel exporter
 * should then be configured without an Authorization header (e.g. for
 * a self-hosted OTLP receiver that doesn't require auth).
 */
fun buildOtlpAuthHeader(instanceId: String, apiKey: String): String? {
    if (instanceId.isBlank() || apiKey.isBlank()) return null
    val token = Base64.encodeToString(
        "$instanceId:$apiKey".toByteArray(Charsets.UTF_8),
        Base64.NO_WRAP,
    )
    return "Basic $token"
}
