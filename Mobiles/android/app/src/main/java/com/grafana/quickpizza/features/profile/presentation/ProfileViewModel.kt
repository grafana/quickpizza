package com.grafana.quickpizza.features.profile.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.grafana.quickpizza.core.o11y.AppLogger
import com.grafana.quickpizza.features.profile.domain.RatingsRepository
import com.grafana.quickpizza.features.profile.models.Rating
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProfileUiState(
    val ratings: List<Rating> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val ratingsRepository: RatingsRepository,
    private val logger: AppLogger,
) : ViewModel() {

    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    init {
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
                _state.update { it.copy(ratings = emptyList()) }
                logger.info("Ratings cleared")
            } catch (e: Exception) {
                logger.error("Failed to clear ratings", e)
            }
        }
    }
}
