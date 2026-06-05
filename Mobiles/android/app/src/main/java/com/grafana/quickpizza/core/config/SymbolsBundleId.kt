package com.grafana.quickpizza.core.config

/**
 * Canonical Android symbols bundle id for upload and OTLP resource `faro.app.bundleId`.
 * Format: `{applicationId}@{versionCode}@{versionName}` (matches `com.grafana.faro` Gradle plugin).
 */
object SymbolsBundleId {
    private const val SEPARATOR = "@"

    fun format(applicationId: String, versionCode: Long, versionName: String): String =
        "$applicationId$SEPARATOR$versionCode$SEPARATOR$versionName"

    fun validate(bundleId: String): Boolean {
        val parts = bundleId.split(SEPARATOR)
        if (parts.size != 3) return false
        if (parts[0].isBlank() || parts[1].isBlank() || parts[2].isBlank()) return false
        return parts[1].all { it.isDigit() }
    }
}
