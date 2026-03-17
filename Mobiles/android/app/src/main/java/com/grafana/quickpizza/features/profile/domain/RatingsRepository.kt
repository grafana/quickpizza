package com.grafana.quickpizza.features.profile.domain

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.grafana.quickpizza.core.api.ApiClient
import com.grafana.quickpizza.features.profile.models.Rating
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RatingsRepository @Inject constructor(
    private val apiClient: ApiClient,
) {
    private val gson = Gson()

    suspend fun getRatings(): List<Rating> = withContext(Dispatchers.IO) {
        val response = apiClient.get("/api/ratings")
        if (!response.isSuccessful) return@withContext emptyList()
        val body = response.body?.string() ?: return@withContext emptyList()
        val wrapper = gson.fromJson(body, RatingsResponse::class.java) ?: return@withContext emptyList()
        wrapper.ratings ?: emptyList()
    }

    suspend fun clearRatings() = withContext(Dispatchers.IO) {
        apiClient.delete("/api/ratings")
    }

    private data class RatingsResponse(
        @SerializedName("ratings") val ratings: List<Rating>?,
    )
}
