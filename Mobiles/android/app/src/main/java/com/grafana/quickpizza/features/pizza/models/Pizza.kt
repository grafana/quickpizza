package com.grafana.quickpizza.features.pizza.models

import com.google.gson.annotations.SerializedName

data class Ingredient(
    @SerializedName("id") val id: Int,
    @SerializedName("name") val name: String,
    @SerializedName("source") val source: String = "",
)

data class Dough(
    @SerializedName("id") val id: Int,
    @SerializedName("name") val name: String,
    @SerializedName("caloriesPerSlice") val caloriesPerSlice: Int? = null,
)

data class Pizza(
    @SerializedName("id") val id: Int,
    @SerializedName("name") val name: String,
    @SerializedName("ingredients") val ingredients: List<Ingredient> = emptyList(),
    @SerializedName("dough") val dough: Dough? = null,
    @SerializedName("tool") val tool: String = "",
)

data class PizzaRecommendation(
    @SerializedName("pizza") val pizza: Pizza,
    @SerializedName("quotation") val quotation: String = "",
    @SerializedName("calories") val calories: Int? = null,
    @SerializedName("vegetarian") val vegetarian: Boolean? = null,
)
