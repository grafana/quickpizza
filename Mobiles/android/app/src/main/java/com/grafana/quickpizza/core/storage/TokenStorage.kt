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
 */
@Singleton
class TokenStorage @Inject constructor(
    @ApplicationContext private val context: Context,
    @ApplicationScope private val applicationScope: CoroutineScope,
) {
    private val dataStore: DataStore<Preferences> = context.authDataStore

    private val flow = dataStore.data.map { prefs ->
        AuthState(
            token = prefs[AuthKeys.token],
            username = prefs[AuthKeys.username],
        )
    }

    private val _state: MutableStateFlow<AuthState> = MutableStateFlow(AuthState(null, null))

    init {
        runBlocking {
            _state.value = flow.first()
        }
        applicationScope.launch {
            flow.collect { _state.value = it }
        }
    }

    val token: String? get() = _state.value.token
    val username: String? get() = _state.value.username

    val tokenFlow: Flow<String?> = _state.map { it.token }.distinctUntilChanged()

    suspend fun setToken(value: String?) = updateString(AuthKeys.token, value)

    suspend fun setUsername(value: String?) = updateString(AuthKeys.username, value)

    suspend fun clear() {
        dataStore.edit { prefs ->
            prefs.remove(AuthKeys.token)
            prefs.remove(AuthKeys.username)
        }
        _state.value = AuthState(null, null)
    }

    private suspend fun updateString(key: Preferences.Key<String>, value: String?) {
        dataStore.edit { prefs ->
            if (value == null) prefs.remove(key) else prefs[key] = value
        }
    }
}
