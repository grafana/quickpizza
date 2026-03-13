package com.grafana.quickpizza.features.pizza.presentation.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.grafana.quickpizza.features.pizza.models.Restrictions
import com.grafana.quickpizza.ui.theme.OrangeAccent

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CustomizeSection(
    restrictions: Restrictions,
    availableTools: List<String>,
    onMaxCaloriesChange: (Int) -> Unit,
    onMinToppingsChange: (Int) -> Unit,
    onMaxToppingsChange: (Int) -> Unit,
    onVegetarianChange: (Boolean) -> Unit,
    onCustomNameChange: (String) -> Unit,
    onToolToggle: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var isExpanded by remember { mutableStateOf(false) }

    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Column {
            // Collapsible header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { isExpanded = !isExpanded }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .background(
                            color = OrangeAccent.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(8.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.Tune,
                        contentDescription = null,
                        tint = OrangeAccent,
                        modifier = Modifier.size(20.dp),
                    )
                }
                Spacer(modifier = Modifier.size(12.dp))
                Text(
                    text = "Customize Your Pizza",
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = if (isExpanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                    contentDescription = if (isExpanded) "Collapse" else "Expand",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AnimatedVisibility(visible = isExpanded) {
                Column(
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .padding(bottom = 16.dp),
                ) {
                    // Calories and toppings row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        OutlinedTextField(
                            value = restrictions.maxCaloriesPerSlice.toString(),
                            onValueChange = { it.toIntOrNull()?.let(onMaxCaloriesChange) },
                            label = { Text("Max Calories") },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = restrictions.minNumberOfToppings.toString(),
                            onValueChange = { it.toIntOrNull()?.let(onMinToppingsChange) },
                            label = { Text("Min Toppings") },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = restrictions.maxNumberOfToppings.toString(),
                            onValueChange = { it.toIntOrNull()?.let(onMaxToppingsChange) },
                            label = { Text("Max Toppings") },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.weight(1f),
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // Vegetarian toggle
                    val vegBgColor = if (restrictions.mustBeVegetarian) Color(0xFFF1F8E9) else Color(0xFFF5F5F5)
                    val vegBorderColor = if (restrictions.mustBeVegetarian) Color(0xFFA5D6A7) else Color(0xFFE0E0E0)
                    val vegIconColor = if (restrictions.mustBeVegetarian) Color(0xFF43A047) else Color(0xFFBDBDBD)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(vegBgColor, RoundedCornerShape(8.dp))
                            .border(1.dp, vegBorderColor, RoundedCornerShape(8.dp))
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Eco,
                            contentDescription = null,
                            tint = vegIconColor,
                            modifier = Modifier.size(20.dp),
                        )
                        Spacer(modifier = Modifier.size(8.dp))
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
                        Spacer(modifier = Modifier.height(4.dp))
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            availableTools.forEach { tool ->
                                FilterChip(
                                    selected = restrictions.excludedTools.contains(tool),
                                    onClick = { onToolToggle(tool) },
                                    label = { Text(tool, style = MaterialTheme.typography.bodySmall) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
