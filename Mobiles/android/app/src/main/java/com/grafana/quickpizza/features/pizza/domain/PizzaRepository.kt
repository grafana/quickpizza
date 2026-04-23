package com.grafana.quickpizza.features.pizza.domain

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import com.grafana.quickpizza.core.api.ApiClient
import com.grafana.quickpizza.core.config.DebugSettingsRepository
import com.grafana.quickpizza.features.pizza.models.Dough
import com.grafana.quickpizza.features.pizza.models.Ingredient
import com.grafana.quickpizza.features.pizza.models.Pizza
import com.grafana.quickpizza.features.pizza.models.PizzaRecommendation
import com.grafana.quickpizza.features.pizza.models.Restrictions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PizzaRepository @Inject constructor(
    private val apiClient: ApiClient,
    private val debugSettings: DebugSettingsRepository,
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
        if (debugSettings.current.useV2PizzaSchema) {
            parseRecommendationV2(body)
        } else {
            gson.fromJson(body, PizzaRecommendation::class.java)
        }
    }

    /**
     * Parses the upcoming v2 response schema. v2 renames `pizza.name` → `pizza.displayName`
     * and `pizza.tool` → `pizza.tooling`. Throws if the expected v2 fields aren't present —
     * this is intentional, the toggle exists to simulate a client that was upgraded ahead
     * of the backend (or vice versa) so we can demo schema-drift telemetry.
     */
    private fun parseRecommendationV2(body: String): PizzaRecommendation {
        val root = JsonParser.parseString(body).asJsonObject
        val pizzaObj = root.getAsJsonObject("pizza") ?: error("v2 schema: missing 'pizza' object")
        val pizza = Pizza(
            id = pizzaObj.requireInt("id"),
            name = pizzaObj.requireString("displayName"),
            tool = pizzaObj.requireString("tooling"),
            ingredients = pizzaObj.getAsJsonArray("ingredients")
                ?.map { gson.fromJson(it, Ingredient::class.java) }
                ?: emptyList(),
            dough = pizzaObj.getAsJsonObject("dough")?.let { gson.fromJson(it, Dough::class.java) },
        )
        return PizzaRecommendation(
            pizza = pizza,
            quotation = root.get("quotation")?.takeIf { !it.isJsonNull }?.asString.orEmpty(),
            calories = root.get("calories")?.takeIf { !it.isJsonNull }?.asInt,
            vegetarian = root.get("vegetarian")?.takeIf { !it.isJsonNull }?.asBoolean,
        )
    }

    private fun JsonObject.requireString(field: String): String =
        get(field)?.takeIf { !it.isJsonNull }?.asString
            ?: error("v2 schema: missing required string field '$field'")

    private fun JsonObject.requireInt(field: String): Int =
        get(field)?.takeIf { !it.isJsonNull }?.asInt
            ?: error("v2 schema: missing required int field '$field'")

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
