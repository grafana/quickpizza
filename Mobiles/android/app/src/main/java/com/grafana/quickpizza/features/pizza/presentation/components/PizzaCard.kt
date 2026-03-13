package com.grafana.quickpizza.features.pizza.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalPizza
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.SuggestionChipDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.grafana.quickpizza.features.pizza.models.PizzaRecommendation
import com.grafana.quickpizza.ui.theme.OrangeAccent

@Composable
fun PizzaCard(recommendation: PizzaRecommendation, modifier: Modifier = Modifier) {
    val pizza = recommendation.pizza
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // "Our Recommendation" subtitle
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.LocalPizza,
                    contentDescription = null,
                    tint = OrangeAccent,
                    modifier = Modifier.size(14.dp),
                )
                Text(
                    text = "Our Recommendation",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = pizza.name,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )

            if (recommendation.vegetarian == true) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "🌿 Vegetarian",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color(0xFF2E7D32),
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color(0xFFE8F5E9))
                        .padding(horizontal = 8.dp, vertical = 2.dp),
                )
            }

            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider(color = Color(0xFFF0F0F0))
            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                pizza.dough?.let { dough ->
                    PizzaDetail(label = "Dough", value = dough.name, modifier = Modifier.weight(1f))
                }
                if (pizza.tool.isNotEmpty()) {
                    PizzaDetail(label = "Tool", value = pizza.tool, modifier = Modifier.weight(1f))
                }
                recommendation.calories?.let { cal ->
                    PizzaDetail(label = "Calories/slice", value = "$cal kcal", modifier = Modifier.weight(1f))
                }
            }

            if (pizza.ingredients.isNotEmpty()) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "Ingredients",
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.align(Alignment.Start),
                )
                Spacer(modifier = Modifier.height(6.dp))
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    pizza.ingredients.chunked(3).forEach { rowItems ->
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            rowItems.forEach { ingredient ->
                                SuggestionChip(
                                    onClick = {},
                                    label = { Text(ingredient.name, style = MaterialTheme.typography.labelSmall) },
                                    colors = SuggestionChipDefaults.suggestionChipColors(
                                        containerColor = Color(0xFFF5F5F5),
                                    ),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PizzaDetail(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
        )
    }
}
