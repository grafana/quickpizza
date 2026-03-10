package com.grafana.quickpizza.features.pizza.models

import com.google.gson.annotations.SerializedName

data class Restrictions(
    @SerializedName("mustBeVegetarian") val mustBeVegetarian: Boolean = false,
    @SerializedName("maxCaloriesPerSlice") val maxCaloriesPerSlice: Int = 1000,
    @SerializedName("minNumberOfToppings") val minNumberOfToppings: Int = 2,
    @SerializedName("maxNumberOfToppings") val maxNumberOfToppings: Int = 5,
    @SerializedName("excludedTools") val excludedTools: List<String> = emptyList(),
    @SerializedName("customName") val customName: String = "",
) {
    companion object {
        val default = Restrictions()
    }
}
