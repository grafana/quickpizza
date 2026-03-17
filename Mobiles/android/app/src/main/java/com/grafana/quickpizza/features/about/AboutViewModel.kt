package com.grafana.quickpizza.features.about

import androidx.lifecycle.ViewModel
import com.grafana.quickpizza.features.auth.domain.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

@HiltViewModel
class AboutViewModel @Inject constructor(
    authRepository: AuthRepository,
) : ViewModel() {
    private val _isAuthenticated = MutableStateFlow(authRepository.isAuthenticated)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()
}
