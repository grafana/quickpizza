package com.grafana.quickpizza.features.about

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp

private data class LinkItem(val label: String, val url: String)

private val links = listOf(
    LinkItem("GitHub Repository", "https://github.com/grafana/mobile-o11y-demo"),
    LinkItem("Grafana Cloud", "https://grafana.com/products/cloud/"),
    LinkItem("OpenTelemetry Android", "https://github.com/open-telemetry/opentelemetry-android"),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen() {
    val context = LocalContext.current

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("About") })

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                text = "QuickPizza Android",
                style = MaterialTheme.typography.headlineSmall,
            )
            Text(
                text = "A native Android demo app showcasing mobile observability with OpenTelemetry. " +
                    "Get pizza recommendations and explore distributed tracing, structured logging, " +
                    "and session management.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Text("Links", style = MaterialTheme.typography.titleMedium)

            links.forEach { link ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = link.label,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            textDecoration = TextDecoration.Underline,
                            color = MaterialTheme.colorScheme.primary,
                        ),
                        modifier = Modifier
                            .padding(16.dp)
                            .clickable {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link.url))
                                context.startActivity(intent)
                            },
                    )
                }
            }
        }
    }
}
