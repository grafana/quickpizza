package com.grafana.quickpizza.features.pizza.presentation.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun RatingButtons(
    onLoveIt: () -> Unit,
    onPass: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        OutlinedButton(
            onClick = onPass,
            modifier = Modifier.weight(1f),
            border = BorderStroke(1.dp, Color(0xFFDAA520)),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFDAA520)),
        ) {
            Text("👎 Pass")
        }
        Button(
            onClick = onLoveIt,
            modifier = Modifier.weight(1f),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE91E63)),
        ) {
            Text("❤️ Love it!")
        }
    }
}
