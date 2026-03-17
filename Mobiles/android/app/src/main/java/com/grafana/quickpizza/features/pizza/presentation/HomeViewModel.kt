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
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import javax.inject.Inject

private const val MIN_CALORIES = 500
private const val MIN_TOPPINGS = 1

data class HomeUiState(
    val quote: String = "",
    val availableTools: List<String> = emptyList(),
    val restrictions: Restrictions = Restrictions.default,
    val recommendation: PizzaRecommendation? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val snackbarMessage: String? = null,
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
        viewModelScope.launch {
            val isAuth = withContext(Dispatchers.IO) { authRepository.isAuthenticated }
            _state.update { it.copy(isAuthenticated = isAuth) }
        }
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
                val recommendation = tracer.withSpan("pizza.get_recommendation") { span ->
                    span.setAttribute("vegetarian", _state.value.restrictions.mustBeVegetarian)
                    span.setAttribute("max_calories", _state.value.restrictions.maxCaloriesPerSlice.toLong())
                    pizzaRepository.getRecommendation(_state.value.restrictions)
                }
                if (recommendation == null && !withContext(Dispatchers.IO) { authRepository.isAuthenticated }) {
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
                tracer.withSpan("pizza.rate") { span ->
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

    fun refreshAuthState() {
        viewModelScope.launch {
            val isAuth = withContext(Dispatchers.IO) { authRepository.isAuthenticated }
            _state.update { state ->
                state.copy(
                    isAuthenticated = isAuth,
                    errorMessage = if (isAuth && state.errorMessage?.contains("sign in", ignoreCase = true) == true) null
                                   else state.errorMessage,
                )
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

    fun clearSnackbar() = _state.update { it.copy(snackbarMessage = null) }

    fun updateMaxCalories(value: Int) {
        val adjusted = maxOf(value, MIN_CALORIES)
        val msg = if (adjusted != value) "Minimum calories is $MIN_CALORIES" else null
        _state.update { it.copy(restrictions = it.restrictions.copy(maxCaloriesPerSlice = adjusted), snackbarMessage = msg) }
    }

    fun updateMinToppings(value: Int) {
        val min = maxOf(value, MIN_TOPPINGS)
        var max = _state.value.restrictions.maxNumberOfToppings
        val msg = when {
            min > max -> { max = min; "Max toppings adjusted to $max to match minimum" }
            min != value -> "Minimum toppings is $MIN_TOPPINGS"
            else -> null
        }
        _state.update { it.copy(restrictions = it.restrictions.copy(minNumberOfToppings = min, maxNumberOfToppings = max), snackbarMessage = msg) }
    }

    fun updateMaxToppings(value: Int) {
        val max = maxOf(value, MIN_TOPPINGS)
        var min = _state.value.restrictions.minNumberOfToppings
        val msg = when {
            max < min -> { min = max; "Min toppings adjusted to $min to match maximum" }
            max != value -> "Minimum toppings is $MIN_TOPPINGS"
            else -> null
        }
        _state.update { it.copy(restrictions = it.restrictions.copy(minNumberOfToppings = min, maxNumberOfToppings = max), snackbarMessage = msg) }
    }

    fun updateVegetarian(value: Boolean) =
        _state.update { it.copy(restrictions = it.restrictions.copy(mustBeVegetarian = value)) }

    fun updateCustomName(value: String) =
        _state.update { it.copy(restrictions = it.restrictions.copy(customName = value)) }
}
