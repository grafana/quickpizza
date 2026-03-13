package com.grafana.quickpizza.features.pizza.domain

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import com.grafana.quickpizza.core.api.ApiClient
import com.grafana.quickpizza.features.pizza.models.PizzaRecommendation
import com.grafana.quickpizza.features.pizza.models.Restrictions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PizzaRepository @Inject constructor(
    private val apiClient: ApiClient,
) {
    private val gson = Gson()

    suspend fun getQuote(): String = withContext(Dispatchers.IO) {
        val response = apiClient.get("/api/quotes")
        if (!response.isSuccessful) return@withContext ""
        val body = response.body?.string() ?: return@withContext ""
        gson.fromJson(body, QuoteResponse::class.java)?.quotes?.randomOrNull() ?: ""
    }

    suspend fun getTools(): List<String> = withContext(Dispatchers.IO) {
        val response = apiClient.get("/api/tools")
        if (!response.isSuccessful) return@withContext emptyList()
        val body = response.body?.string() ?: return@withContext emptyList()
        val type = object : TypeToken<ToolsResponse>() {}.type
        val toolsResponse: ToolsResponse = gson.fromJson(body, type) ?: return@withContext emptyList()
        toolsResponse.tools
    }

    suspend fun getRecommendation(restrictions: Restrictions): PizzaRecommendation? = withContext(Dispatchers.IO) {
        val response = apiClient.post("/api/pizza", body = restrictions)
        if (response.code == 401) return@withContext null
        if (!response.isSuccessful) error("Failed to get recommendation: HTTP ${response.code}")
        val body = response.body?.string() ?: error("Empty response body")
        gson.fromJson(body, PizzaRecommendation::class.java)
    }

    suspend fun ratePizza(pizzaId: Int, stars: Int) = withContext(Dispatchers.IO) {
        val response = apiClient.post("/api/ratings", body = RatingRequest(pizzaId, stars))
        if (!response.isSuccessful) error("Failed to submit rating: HTTP ${response.code}")
    }

    private data class QuoteResponse(@SerializedName("quotes") val quotes: List<String>?)
    private data class ToolsResponse(@SerializedName("tools") val tools: List<String>)
    private data class RatingRequest(
        @SerializedName("pizza_id") val pizzaId: Int,
        @SerializedName("stars") val stars: Int,
    )
}
