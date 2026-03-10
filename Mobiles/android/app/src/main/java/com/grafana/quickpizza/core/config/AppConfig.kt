package com.grafana.quickpizza.core.config

import android.content.Context
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AppConfig @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val config: ConfigFile by lazy { loadConfig() }

    val otlpEndpoint: String get() = config.otlpEndpoint.trim()
    val otlpAuthHeader: String get() = config.otlpAuthHeader.trim()
    val appVersion: String get() = runCatching {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "unknown"
    }.getOrDefault("unknown")

    val baseUrl: String
        get() {
            val url = config.baseUrl.trim()
            return if (url.isNotEmpty()) url else defaultBaseUrl
        }

    // Android emulator uses 10.0.2.2 to reach the host machine's localhost.
    // This matches the Flutter ConfigService behavior on Android.
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
        @SerializedName("OTLP_AUTH_HEADER") val otlpAuthHeader: String = "",
        @SerializedName("BASE_URL") val baseUrl: String = "",
    )
}
