package com.grafana.quickpizza.core.storage

import android.content.Context
import android.content.SharedPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TokenStorage @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

    var token: String?
        get() = prefs.getString(KEY_TOKEN, null)
        set(value) {
            if (value == null) {
                prefs.edit().remove(KEY_TOKEN).apply()
            } else {
                prefs.edit().putString(KEY_TOKEN, value).apply()
            }
        }

    var username: String?
        get() = prefs.getString(KEY_USERNAME, null)
        set(value) {
            if (value == null) {
                prefs.edit().remove(KEY_USERNAME).apply()
            } else {
                prefs.edit().putString(KEY_USERNAME, value).apply()
            }
        }

    fun clear() {
        token = null
        username = null
    }

    companion object {
        private const val PREFS_FILE = "quickpizza_prefs"
        private const val KEY_TOKEN = "auth_token"
        private const val KEY_USERNAME = "auth_username"
    }
}
