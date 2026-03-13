package com.grafana.quickpizza.features.profile.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.grafana.quickpizza.core.o11y.AppLogger
import com.grafana.quickpizza.features.auth.domain.AuthRepository
import com.grafana.quickpizza.features.profile.domain.RatingsRepository
import com.grafana.quickpizza.features.profile.models.Rating
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

data class ProfileUiState(
    val username: String? = null,
    val ratings: List<Rating> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val showRatingsClearedMessage: Boolean = false,
)

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val ratingsRepository: RatingsRepository,
    private val authRepository: AuthRepository,
    private val logger: AppLogger,
) : ViewModel() {

    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            val name = withContext(Dispatchers.IO) { authRepository.username }
            _state.update { it.copy(username = name) }
        }
        loadRatings()
    }

    private fun loadRatings() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            try {
                val ratings = ratingsRepository.getRatings()
                _state.update { it.copy(ratings = ratings) }
            } catch (e: Exception) {
                logger.error("Failed to load ratings", e)
                _state.update { it.copy(errorMessage = e.message) }
            } finally {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }

    fun clearRatings() {
        viewModelScope.launch {
            try {
                ratingsRepository.clearRatings()
                _state.update { it.copy(ratings = emptyList(), showRatingsClearedMessage = true) }
                logger.info("Ratings cleared")
            } catch (e: Exception) {
                logger.error("Failed to clear ratings", e)
            }
        }
    }

    fun onRatingsClearedMessageShown() {
        _state.update { it.copy(showRatingsClearedMessage = false) }
    }

    fun signOut(onSignedOut: () -> Unit) {
        authRepository.logout()
        logger.info("User signed out")
        onSignedOut()
    }
}
