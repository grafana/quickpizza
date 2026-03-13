package com.grafana.quickpizza.features.auth.domain

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.grafana.quickpizza.core.api.ApiClient
import com.grafana.quickpizza.core.storage.TokenStorage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val apiClient: ApiClient,
    private val tokenStorage: TokenStorage,
) {
    val isAuthenticated: Boolean
        get() = tokenStorage.token != null

    val username: String?
        get() = tokenStorage.username

    suspend fun login(username: String, password: String) = withContext(Dispatchers.IO) {
        val response = apiClient.post(
            "/api/users/token/login",
            body = LoginRequest(username, password),
            includeAuth = false,
        )
        if (!response.isSuccessful) {
            error("Login failed: HTTP ${response.code}")
        }
        val body = response.body?.string() ?: error("Empty response body")
        val loginResponse = Gson().fromJson(body, LoginResponse::class.java)
        tokenStorage.token = loginResponse.token
        tokenStorage.username = username
    }

    fun logout() {
        tokenStorage.clear()
    }

    private data class LoginRequest(
        val username: String,
        val password: String,
    )

    private data class LoginResponse(
        @SerializedName("token") val token: String,
    )
}
