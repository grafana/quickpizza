package com.grafana.quickpizza.features.pizza.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.grafana.quickpizza.core.config.DebugSettingsRepository
import com.grafana.quickpizza.core.o11y.AppLogger
import com.grafana.quickpizza.core.o11y.AppTracer
import com.grafana.quickpizza.features.auth.domain.AuthRepository
import com.grafana.quickpizza.features.pizza.domain.PizzaRepository
import com.grafana.quickpizza.features.pizza.models.PizzaRecommendation
import com.grafana.quickpizza.features.pizza.models.Restrictions
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
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
    private val debugSettings: DebugSettingsRepository,
    private val logger: AppLogger,
    private val tracer: AppTracer,
) : ViewModel() {

    private val _state = MutableStateFlow(HomeUiState())
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    init {
        observeAuthState()
        observeAuthForToolsRefresh()
        loadQuote()
    }

    /**
     * Mirrors `_state.isAuthenticated` to the live token state. Also clears any
     * stale "please sign in" error on a logged-out → logged-in transition.
     */
    private fun observeAuthState() {
        viewModelScope.launch {
            authRepository.isAuthenticatedFlow.collect { isAuthed ->
                _state.update { state ->
                    val clearError = isAuthed &&
                        state.errorMessage?.contains("sign in", ignoreCase = true) == true
                    state.copy(
                        isAuthenticated = isAuthed,
                        errorMessage = if (clearError) null else state.errorMessage,
                    )
                }
            }
        }
    }

    /**
     * Refetches the available tools list whenever auth state changes — `/api/tools`
     * requires a valid token, so a cold start while logged out leaves the list
     * empty until we re-issue the request after login.
     *
     * The [DebugSettingsRepository.skipAuthDepInTools] toggle disables the auth
     * dependency to reproduce the bug for demos.
     */
    @OptIn(ExperimentalCoroutinesApi::class)
    private fun observeAuthForToolsRefresh() {
        viewModelScope.launch {
            debugSettings.state
                .map { it.skipAuthDepInTools }
                .distinctUntilChanged()
                .flatMapLatest { skipAuth ->
                    if (skipAuth) flowOf(Unit)
                    else authRepository.isAuthenticatedFlow.map { }
                }
                .collect { refetchTools() }
        }
    }

    private suspend fun refetchTools() {
        val tools = runCatching { pizzaRepository.getTools() }.getOrDefault(emptyList())
        _state.update { it.copy(availableTools = tools) }
    }

    private fun loadQuote() {
        viewModelScope.launch {
            val quote = runCatching { pizzaRepository.getQuote() }.getOrDefault("")
            _state.update { it.copy(quote = quote) }
        }
    }

    fun getRecommendation() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null, ratingSubmitted = false, recommendation = null) }
            try {
                val recommendation = tracer.withSpan("pizza.get_recommendation") { span ->
                    span.setAttribute("pizza.vegetarian", _state.value.restrictions.mustBeVegetarian)
                    span.setAttribute("pizza.max_calories", _state.value.restrictions.maxCaloriesPerSlice.toLong())
                    val result = pizzaRepository.getRecommendation(_state.value.restrictions)
                    if (result != null) {
                        span.setAttribute("pizza.id", result.pizza.id.toLong())
                        span.setAttribute("pizza.name", result.pizza.name)
                    }
                    result
                }
                if (recommendation == null && !_state.value.isAuthenticated) {
                    _state.update { it.copy(errorMessage = "Please sign in to get pizza recommendations") }
                } else {
                    if (recommendation != null) {
                        logger.info(
                            "Pizza recommendation fetched",
                            mapOf(
                                "pizza_id" to recommendation.pizza.id.toString(),
                                "pizza_name" to recommendation.pizza.name,
                            ),
                        )
                    }
                    _state.update { it.copy(recommendation = recommendation) }
                }
            } catch (e: Exception) {
                logger.exception("Failed to get recommendation", e)
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
                    span.setAttribute("pizza.id", pizza.id.toLong())
                    span.setAttribute("pizza.stars", stars.toLong())
                    pizzaRepository.ratePizza(pizza.id, stars)
                }
                _state.update { it.copy(ratingSubmitted = true) }
                logger.info(
                    "Pizza rated",
                    mapOf("pizza_id" to pizza.id.toString(), "stars" to stars.toString()),
                )
            } catch (e: Exception) {
                logger.exception("Rating failed", e)
                _state.update { it.copy(errorMessage = "Failed to submit rating") }
            }
        }
    }

    fun logout(onLoggedOut: () -> Unit) {
        viewModelScope.launch {
            authRepository.logout()
            // isAuthenticated is updated by observeAuthState() via the token flow.
            _state.update {
                it.copy(
                    recommendation = null,
                    errorMessage = null,
                    ratingSubmitted = false,
                )
            }
            onLoggedOut()
        }
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
