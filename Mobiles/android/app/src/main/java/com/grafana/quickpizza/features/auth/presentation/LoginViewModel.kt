package com.grafana.quickpizza.features.auth.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.grafana.quickpizza.core.o11y.AppLogger
import com.grafana.quickpizza.core.o11y.AppTracer
import com.grafana.quickpizza.features.auth.domain.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LoginUiState(
    val username: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val logger: AppLogger,
    private val tracer: AppTracer,
) : ViewModel() {

    private val _state = MutableStateFlow(LoginUiState())
    val state: StateFlow<LoginUiState> = _state.asStateFlow()

    fun onUsernameChange(value: String) = _state.update { it.copy(username = value) }
    fun onPasswordChange(value: String) = _state.update { it.copy(password = value) }

    fun login(onSuccess: () -> Unit) {
        val username = _state.value.username.trim()
        val password = _state.value.password
        if (username.isEmpty() || password.isEmpty()) {
            _state.update { it.copy(errorMessage = "Username and password are required") }
            return
        }

        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                tracer.withSpan("auth.login") { span ->
                    span.setAttribute("user.name", username)
                    authRepository.login(username, password)
                }
                logger.info("User logged in", mapOf("username" to username))
                onSuccess()
            } catch (e: Exception) {
                logger.error("Login failed", e)
                _state.update { it.copy(errorMessage = e.message ?: "Login failed") }
            } finally {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }
}
