package com.grafana.quickpizza.features.pizza.presentation.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.grafana.quickpizza.features.pizza.models.Restrictions

@Composable
fun CustomizeSection(
    restrictions: Restrictions,
    availableTools: List<String>,
    onMaxCaloriesChange: (Int) -> Unit,
    onVegetarianChange: (Boolean) -> Unit,
    onCustomNameChange: (String) -> Unit,
    onToolToggle: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Customize", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(12.dp))

            // Max calories slider
            Text(
                "Max calories per slice: ${restrictions.maxCaloriesPerSlice}",
                style = MaterialTheme.typography.bodySmall,
            )
            Slider(
                value = restrictions.maxCaloriesPerSlice.toFloat(),
                onValueChange = { onMaxCaloriesChange(it.toInt()) },
                valueRange = 300f..2000f,
                steps = 17,
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Vegetarian toggle
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Vegetarian only", modifier = Modifier.weight(1f))
                Switch(
                    checked = restrictions.mustBeVegetarian,
                    onCheckedChange = onVegetarianChange,
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Custom name
            OutlinedTextField(
                value = restrictions.customName,
                onValueChange = onCustomNameChange,
                label = { Text("Custom name (optional)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )

            // Excluded tools
            if (availableTools.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text("Exclude tools:", style = MaterialTheme.typography.bodySmall)
                availableTools.forEach { tool ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(
                            checked = restrictions.excludedTools.contains(tool),
                            onCheckedChange = { onToolToggle(tool) },
                        )
                        Text(tool, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }
}
