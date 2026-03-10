package com.grafana.quickpizza.features.pizza.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.grafana.quickpizza.core.o11y.AppLogger
import com.grafana.quickpizza.core.o11y.AppTracer
import com.grafana.quickpizza.features.auth.domain.AuthRepository
import com.grafana.quickpizza.features.pizza.domain.PizzaRepository
import com.grafana.quickpizza.features.pizza.models.PizzaRecommendation
import com.grafana.quickpizza.features.pizza.models.Restrictions
import dagger.hilt.android.lifecycle.HiltViewModel
import io.opentelemetry.api.trace.SpanKind
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeUiState(
    val quote: String = "",
    val availableTools: List<String> = emptyList(),
    val restrictions: Restrictions = Restrictions.default,
    val recommendation: PizzaRecommendation? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val ratingSubmitted: Boolean = false,
    val isAuthenticated: Boolean = false,
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val pizzaRepository: PizzaRepository,
    private val authRepository: AuthRepository,
    private val logger: AppLogger,
    private val tracer: AppTracer,
) : ViewModel() {

    private val _state = MutableStateFlow(HomeUiState())
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    init {
        _state.update { it.copy(isAuthenticated = authRepository.isAuthenticated) }
        loadInitialData()
    }

    private fun loadInitialData() {
        viewModelScope.launch {
            val quoteDeferred = async { runCatching { pizzaRepository.getQuote() }.getOrDefault("") }
            val toolsDeferred = async { runCatching { pizzaRepository.getTools() }.getOrDefault(emptyList()) }
            _state.update { it.copy(quote = quoteDeferred.await(), availableTools = toolsDeferred.await()) }
        }
    }

    fun getRecommendation() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null, ratingSubmitted = false, recommendation = null) }
            try {
                val recommendation = tracer.withSpan("pizza.get_recommendation", SpanKind.CLIENT) { span ->
                    span.setAttribute("vegetarian", _state.value.restrictions.mustBeVegetarian)
                    span.setAttribute("max_calories", _state.value.restrictions.maxCaloriesPerSlice.toLong())
                    pizzaRepository.getRecommendation(_state.value.restrictions)
                }
                if (recommendation == null && !authRepository.isAuthenticated) {
                    _state.update { it.copy(errorMessage = "Please sign in to get pizza recommendations") }
                } else {
                    _state.update { it.copy(recommendation = recommendation) }
                }
            } catch (e: Exception) {
                logger.error("Failed to get recommendation", e)
                _state.update { it.copy(errorMessage = e.message ?: "Failed to get recommendation") }
            } finally {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }

    fun ratePizza(stars: Int) {
        val pizza = _state.value.recommendation?.pizza ?: return
        viewModelScope.launch {
            try {
                tracer.withSpan("pizza.rate", SpanKind.CLIENT) { span ->
                    span.setAttribute("pizza_id", pizza.id.toLong())
                    span.setAttribute("stars", stars.toLong())
                    pizzaRepository.ratePizza(pizza.id, stars)
                }
                _state.update { it.copy(ratingSubmitted = true) }
                logger.info(
                    "Pizza rated",
                    mapOf("pizza_id" to pizza.id.toString(), "stars" to stars.toString()),
                )
            } catch (e: Exception) {
                logger.error("Rating failed", e)
                _state.update { it.copy(errorMessage = "Failed to submit rating") }
            }
        }
    }

    fun logout(onLoggedOut: () -> Unit) {
        authRepository.logout()
        _state.update {
            it.copy(
                isAuthenticated = false,
                recommendation = null,
                errorMessage = null,
                ratingSubmitted = false,
            )
        }
        onLoggedOut()
    }

    fun toggleExcludedTool(tool: String) {
        _state.update { current ->
            val tools = current.restrictions.excludedTools.toMutableList()
            if (tools.contains(tool)) tools.remove(tool) else tools.add(tool)
            current.copy(restrictions = current.restrictions.copy(excludedTools = tools))
        }
    }

    fun updateMaxCalories(value: Int) =
        _state.update { it.copy(restrictions = it.restrictions.copy(maxCaloriesPerSlice = value)) }

    fun updateMinToppings(value: Int) =
        _state.update { it.copy(restrictions = it.restrictions.copy(minNumberOfToppings = value)) }

    fun updateMaxToppings(value: Int) =
        _state.update { it.copy(restrictions = it.restrictions.copy(maxNumberOfToppings = value)) }

    fun updateVegetarian(value: Boolean) =
        _state.update { it.copy(restrictions = it.restrictions.copy(mustBeVegetarian = value)) }

    fun updateCustomName(value: String) =
        _state.update { it.copy(restrictions = it.restrictions.copy(customName = value)) }
}
