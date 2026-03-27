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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LocalPizza
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.Restaurant
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
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
        Column(modifier = Modifier.padding(16.dp)) {
            // Header: icon + "Our Recommendation" + pizza name (left-aligned, like Flutter)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Filled.LocalPizza,
                    contentDescription = null,
                    tint = OrangeAccent,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Our Recommendation",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = pizza.name,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )

            if (recommendation.vegetarian == true) {
                Spacer(modifier = Modifier.height(4.dp))
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

            // Details: each on its own row with icon, like Flutter
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                pizza.dough?.let { dough ->
                    DetailRow(
                        icon = Icons.Filled.Layers,
                        label = "Dough",
                        value = dough.name,
                    )
                }
                if (pizza.tool.isNotEmpty()) {
                    DetailRow(
                        icon = Icons.Filled.Restaurant,
                        label = "Tool",
                        value = pizza.tool,
                    )
                }
                recommendation.calories?.let { cal ->
                    DetailRow(
                        icon = Icons.Filled.LocalFireDepartment,
                        label = "Calories",
                        value = "$cal per slice",
                    )
                }
            }

            if (pizza.ingredients.isNotEmpty()) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "Ingredients",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.height(6.dp))
                ChipFlow(horizontalSpacing = 6.dp, verticalSpacing = 6.dp) {
                    pizza.ingredients.forEach { ingredient ->
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

/** Simple wrapping chip layout using Compose's Layout — no experimental APIs required. */
@Composable
private fun ChipFlow(
    horizontalSpacing: Dp = 6.dp,
    verticalSpacing: Dp = 6.dp,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Layout(content = content, modifier = modifier.fillMaxWidth()) { measurables, constraints ->
        val hGap = horizontalSpacing.roundToPx()
        val vGap = verticalSpacing.roundToPx()
        val placeables = measurables.map { it.measure(constraints.copy(minWidth = 0)) }

        // Build rows by fitting placeables left-to-right
        data class RowData(val items: List<androidx.compose.ui.layout.Placeable>)
        val rows = mutableListOf<RowData>()
        var rowItems = mutableListOf<androidx.compose.ui.layout.Placeable>()
        var rowWidth = 0

        for (p in placeables) {
            val needed = if (rowItems.isEmpty()) p.width else rowWidth + hGap + p.width
            if (rowItems.isNotEmpty() && needed > constraints.maxWidth) {
                rows += RowData(rowItems)
                rowItems = mutableListOf()
                rowWidth = 0
            }
            rowItems += p
            rowWidth = if (rowItems.size == 1) p.width else rowWidth + hGap + p.width
        }
        if (rowItems.isNotEmpty()) rows += RowData(rowItems)

        val totalHeight = rows.sumOf { row -> row.items.maxOf { it.height } }
            .plus((rows.size - 1).coerceAtLeast(0) * vGap)

        layout(constraints.maxWidth, totalHeight) {
            var y = 0
            rows.forEach { row ->
                var x = 0
                val rowHeight = row.items.maxOf { it.height }
                row.items.forEach { p ->
                    p.placeRelative(x, y + (rowHeight - p.height) / 2)
                    x += p.width + hGap
                }
                y += rowHeight + vGap
            }
        }
    }
}

@Composable
private fun DetailRow(icon: ImageVector, label: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(16.dp),
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = "$label: ",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
        )
    }
}
