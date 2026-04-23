package com.grafana.quickpizza.features.debug

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Shown at the top of the Debug and Config screens whenever the saved
 * URL overrides differ from the URLs currently in use in the session.
 *
 * Renders nothing when no restart is needed.
 */
@Composable
fun RestartRequiredBanner(state: RestartBannerState, modifier: Modifier = Modifier) {
    val visible = state as? RestartBannerState.Visible ?: return
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = AmberContainer),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Icon(Icons.Default.Warning, contentDescription = null, tint = AmberOnContainer)
            Column {
                Text(
                    "Restart required",
                    color = AmberOnContainer,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleSmall,
                )
                Text(
                    "Kill and relaunch the app for the new ${visible.changedLabel} to take effect.",
                    color = AmberOnContainer,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

private val AmberContainer = Color(0xFFFFECB3)
private val AmberOnContainer = Color(0xFF7A4F00)
