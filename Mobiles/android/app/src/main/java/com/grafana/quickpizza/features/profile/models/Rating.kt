package com.grafana.quickpizza.features.profile.models

import com.google.gson.annotations.SerializedName

data class Rating(
    @SerializedName("id") val id: Int,
    @SerializedName("pizzaID") val pizzaId: Int,
    @SerializedName("stars") val stars: Int,
)
