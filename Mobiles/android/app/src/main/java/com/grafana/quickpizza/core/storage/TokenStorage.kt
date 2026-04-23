package com.grafana.quickpizza.core.storage

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.grafana.quickpizza.core.config.ApplicationScope
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import javax.inject.Inject
import javax.inject.Singleton

private data class AuthState(val token: String?, val username: String?)

private object AuthKeys {
    val token = stringPreferencesKey("auth_token")
    val username = stringPreferencesKey("auth_username")
}

private val Context.authDataStore: DataStore<Preferences> by preferencesDataStore(name = "auth")

/**
 * Persists the user's auth token and username.
 *
 * Reads ([token], [username]) are synchronous — they're called on every HTTP
 * request and cannot afford a coroutine round-trip. Backed by a hot
 * [StateFlow] seeded at construction with a one-shot blocking DataStore read,
 * then kept in sync via [applicationScope].
 *
 * Writes ([setToken], [setUsername], [clear]) are `suspend` — DataStore writes
 * are atomic and never touch the main thread.
 */
@Singleton
class TokenStorage @Inject constructor(
    @ApplicationContext private val context: Context,
    @ApplicationScope private val applicationScope: CoroutineScope,
) {
    private val dataStore: DataStore<Preferences> = context.authDataStore

    private val flow = dataStore.data.map { prefs ->
        AuthState(token = prefs[AuthKeys.token], username = prefs[AuthKeys.username])
    }

    private val _state: MutableStateFlow<AuthState> = MutableStateFlow(
        runBlocking { flow.first() },
    )

    init {
        applicationScope.launch {
            flow.collect { _state.value = it }
        }
    }

    val token: String? get() = _state.value.token
    val username: String? get() = _state.value.username

    /**
     * Hot stream of token-presence changes. Emits the current value on subscription
     * and a new value whenever [setToken] / [clear] mutate the underlying DataStore.
     * Consumers that need to react to login / logout should observe this rather than
     * polling [token] on a lifecycle event.
     */
    val tokenFlow: Flow<String?> = _state.map { it.token }.distinctUntilChanged()

    suspend fun setToken(value: String?) = updateString(AuthKeys.token, value)
    suspend fun setUsername(value: String?) = updateString(AuthKeys.username, value)

    suspend fun clear() {
        dataStore.edit { prefs ->
            prefs.remove(AuthKeys.token)
            prefs.remove(AuthKeys.username)
        }
    }

    private suspend fun updateString(key: Preferences.Key<String>, value: String?) {
        dataStore.edit { prefs ->
            if (value == null) prefs.remove(key) else prefs[key] = value
        }
    }
}
