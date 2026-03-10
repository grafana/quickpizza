package com.grafana.quickpizza.features.pizza.models

import com.google.gson.annotations.SerializedName

data class Ingredient(
    @SerializedName("id") val id: Int,
    @SerializedName("name") val name: String,
    @SerializedName("source") val source: String = "",
)

data class Pizza(
    @SerializedName("id") val id: Int,
    @SerializedName("name") val name: String,
    @SerializedName("ingredients") val ingredients: List<Ingredient> = emptyList(),
)

data class PizzaRecommendation(
    @SerializedName("pizza") val pizza: Pizza,
    @SerializedName("quotation") val quotation: String = "",
)
