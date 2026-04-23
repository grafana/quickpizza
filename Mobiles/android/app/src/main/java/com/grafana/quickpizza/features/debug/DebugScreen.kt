package com.grafana.quickpizza.features.debug

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.grafana.quickpizza.core.config.DebugSettings
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DebugScreen(
    onNavigateToConfig: () -> Unit,
    viewModel: DebugViewModel = hiltViewModel(),
) {
    val ui by viewModel.state.collectAsState()

    // Auto-clear the transient action message after 3s — same UX as the Flutter app.
    LaunchedEffect(ui.lastActionMessage) {
        if (ui.lastActionMessage != null) {
            delay(3000)
            viewModel.clearLastAction()
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Debug") },
            actions = {
                if (ui.settings.hasActiveOverrides) {
                    TextButton(onClick = viewModel::resetAll) {
                        Text("Reset All")
                    }
                }
            },
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            RestartRequiredBanner(ui.restartBanner)

            ConfigEntryCard(onClick = onNavigateToConfig)

            Text(
                "Use these tools to simulate issues and exercise the observability " +
                    "instrumentation during demos.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            ErrorSimulationSection(settings = ui.settings, viewModel = viewModel)

            ClientDiagnosticsSection(viewModel = viewModel)

            OTelSdkSection(settings = ui.settings, viewModel = viewModel)

            ui.lastActionMessage?.let { LastActionCard(message = it) }
        }
    }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConfigEntryCard(onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Settings, contentDescription = null)
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text("Config", style = MaterialTheme.typography.titleSmall)
                Text(
                    "Change backend URL, OTLP endpoint, and OTLP credentials (requires restart)",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = "Open config",
            )
        }
    }
}

@Composable
private fun OTelSdkSection(settings: DebugSettings, viewModel: DebugViewModel) {
    SectionHeader("OpenTelemetry SDK")
    Text(
        "Tunes the OTel-Android SDK behavior. Read once at app startup — toggling " +
            "requires a restart for the new value to take effect.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Card(modifier = Modifier.fillMaxWidth()) {
        // Switch UX is "ON = active override". Disk buffering is enabled by default
        // in the SDK; flipping this ON disables it and trades offline resilience for
        // ~30–45s lower end-to-end latency — useful for live demos.
        ToggleRow(
            title = "Disable disk buffering",
            subtitle = "Default: off (SDK buffers to disk, ~30–45s latency). Turn on for " +
                "near-real-time export (~1–6s) — signals are lost if the app is offline.",
            checked = settings.disableDiskBuffering,
            onCheckedChange = viewModel::setDisableDiskBuffering,
        )
    }
}

@Composable
private fun ErrorSimulationSection(settings: DebugSettings, viewModel: DebugViewModel) {
    SectionHeader("Error Simulation")
    Text(
        "Toggle these to simulate backend issues, client-side faults, and version drift. " +
            "Takes effect immediately — no restart needed.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Card(modifier = Modifier.fillMaxWidth()) {
        Column {
            ToggleRow(
                title = "Slow Recommendations",
                subtitle = "Adds delay to pizza recommendations",
                checked = settings.slowRecommendations,
                onCheckedChange = viewModel::setSlowRecommendations,
            )
            HorizontalDivider()
            ToggleRow(
                title = "Slow Ingredients",
                subtitle = "Adds delay to ingredient loading",
                checked = settings.slowIngredients,
                onCheckedChange = viewModel::setSlowIngredients,
            )
            HorizontalDivider()
            ToggleRow(
                title = "Error on Recommendations",
                subtitle = "Forces server errors on recommendations",
                checked = settings.errorOnRecommendations,
                onCheckedChange = viewModel::setErrorOnRecommendations,
            )
            HorizontalDivider()
            ToggleRow(
                title = "Error on Ingredients",
                subtitle = "Forces server errors on ingredient loading",
                checked = settings.errorOnIngredients,
                onCheckedChange = viewModel::setErrorOnIngredients,
            )
            HorizontalDivider()
            ToggleRow(
                title = "Use v2 pizza response schema",
                subtitle = "Experimental — simulates a client/backend schema drift",
                checked = settings.useV2PizzaSchema,
                onCheckedChange = viewModel::setUseV2PizzaSchema,
            )
            HorizontalDivider()
            ToggleRow(
                title = "Skip auth dep in tools provider",
                subtitle = "Tools list won't refresh on login/logout — reproduces the bug",
                checked = settings.skipAuthDepInTools,
                onCheckedChange = viewModel::setSkipAuthDepInTools,
            )
        }
    }
}

@Composable
private fun ClientDiagnosticsSection(viewModel: DebugViewModel) {
    SectionHeader("Client Diagnostics")

    QuickSignalsCard(viewModel)

    DiagnosticActionCard(
        title = "Handled Exception",
        description = "Throws an exception inside a try/catch and reports it via the OTel logger as " +
            "an exception log record. Tests the manual reporting path.",
        buttonText = "Send Handled Exception",
        onClick = viewModel::logTestException,
    )

    DiagnosticActionCard(
        title = "ANR",
        description = "Blocks the main thread for 6 seconds, exceeding Android's 5s ANR threshold. " +
            "The system shows an ANR dialog and the OTel agent reports it.",
        buttonText = "Trigger ANR",
        danger = true,
        onClick = viewModel::triggerAnr,
    )

    CrashCard(viewModel)
}

@Composable
private fun QuickSignalsCard(viewModel: DebugViewModel) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Quick Signals", style = MaterialTheme.typography.titleSmall)
            Text(
                "Emit one-off signals (logs and custom events) to verify the OTel pipeline end-to-end.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(4.dp))
            Button(modifier = Modifier.fillMaxWidth(), onClick = viewModel::sendDebugLog) {
                Text("Send Debug Log")
            }
            Button(modifier = Modifier.fillMaxWidth(), onClick = viewModel::sendErrorLog) {
                Text("Send Error Log")
            }
            Button(modifier = Modifier.fillMaxWidth(), onClick = viewModel::sendCustomEvent) {
                Text("Send Custom Event")
            }
        }
    }
}

@Composable
private fun CrashCard(viewModel: DebugViewModel) {
    var pending by rememberSaveable { mutableStateOf<CrashKind?>(null) }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                "Crash Reporting",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
            Text(
                "Throws an unhandled exception. The OTel-Android agent's CrashReporter persists " +
                    "the crash to disk and the exporter delivers it on the next app launch — the OS " +
                    "terminates the app immediately.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
            Spacer(Modifier.height(4.dp))
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { pending = CrashKind.RuntimeException },
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
            ) {
                Text("Crash (RuntimeException)")
            }
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = { pending = CrashKind.NullPointer },
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
            ) {
                Text("Crash (NPE)")
            }
        }
    }

    pending?.let { kind ->
        AlertDialog(
            onDismissRequest = { pending = null },
            title = { Text(kind.dialogTitle) },
            text = { Text(kind.dialogBody) },
            confirmButton = {
                TextButton(onClick = {
                    pending = null
                    when (kind) {
                        CrashKind.RuntimeException -> viewModel.triggerCrashRuntimeException()
                        CrashKind.NullPointer -> viewModel.triggerCrashNullPointer()
                    }
                }) { Text("Crash now", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { pending = null }) { Text("Cancel") }
            },
        )
    }
}

private enum class CrashKind(val dialogTitle: String, val dialogBody: String) {
    RuntimeException(
        dialogTitle = "Trigger crash?",
        dialogBody = "The app will terminate. Relaunch it to see the crash report in your o11y backend.",
    ),
    NullPointer(
        dialogTitle = "Trigger simulated NPE?",
        dialogBody = "Simulates a real-world null-dereference bug. The app will terminate. Relaunch " +
            "it to see the crash report in your o11y backend.",
    ),
}

// ---------------------------------------------------------------------------
// Reusable building blocks
// ---------------------------------------------------------------------------

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Bold,
    )
}

@Composable
private fun ToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            Text(
                subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun DiagnosticActionCard(
    title: String,
    description: String,
    buttonText: String,
    onClick: () -> Unit,
    danger: Boolean = false,
) {
    // For non-danger cards, fall through to the default Card colors so the
    // surface tint matches the other cards on the screen (Quick Signals etc).
    // Overriding to MaterialTheme.colorScheme.surface here would make the card
    // blend into the screen background and look like it has no container.
    val cardColors = if (danger) {
        CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
    } else {
        CardDefaults.cardColors()
    }
    val titleColor = if (danger) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onSurface
    val bodyColor = titleColor.copy(alpha = 0.85f)

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = cardColors,
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall, color = titleColor)
            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = bodyColor,
            )
            Spacer(Modifier.height(4.dp))
            Button(
                modifier = Modifier.fillMaxWidth(),
                onClick = onClick,
                colors = if (danger) {
                    ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                } else {
                    ButtonDefaults.buttonColors()
                },
            ) {
                Text(buttonText)
            }
        }
    }
}

@Composable
private fun LastActionCard(message: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = SuccessContainer),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = SuccessOnContainer)
            Text(message, color = SuccessOnContainer)
        }
    }
}

private val SuccessContainer = Color(0xFFE8F5E9)
private val SuccessOnContainer = Color(0xFF1B5E20)
