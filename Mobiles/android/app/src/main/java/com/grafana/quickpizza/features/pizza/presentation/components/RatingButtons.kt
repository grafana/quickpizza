package com.grafana.quickpizza.features.pizza.presentation.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun RatingButtons(
    onLoveIt: () -> Unit,
    onNoThanks: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Button(onClick = onLoveIt, modifier = Modifier.weight(1f)) {
            Text("❤️ Love it")
        }
        OutlinedButton(onClick = onNoThanks, modifier = Modifier.weight(1f)) {
            Text("👎 No thanks")
        }
    }
}
