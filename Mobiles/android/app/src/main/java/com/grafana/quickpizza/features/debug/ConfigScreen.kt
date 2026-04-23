package com.grafana.quickpizza.features.debug

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConfigScreen(
    onBack: () -> Unit,
    viewModel: ConfigViewModel = hiltViewModel(),
) {
    val ui by viewModel.state.collectAsState()

    // Seed editable fields once from the persisted overrides. We don't
    // reactively re-bind on every state change — that would clobber
    // in-progress typing.
    var backendField by rememberSaveable { mutableStateOf(ui.savedBackendOverride.orEmpty()) }
    var otlpField by rememberSaveable { mutableStateOf(ui.savedOtlpOverride.orEmpty()) }
    var instanceIdField by rememberSaveable { mutableStateOf(ui.savedOtlpInstanceIdOverride.orEmpty()) }
    var apiKeyField by rememberSaveable { mutableStateOf(ui.savedOtlpApiKeyOverride.orEmpty()) }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Config") },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
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

            Text(
                "Override the URLs and OTLP credentials used by this app. Changes only take effect " +
                    "after you kill and restart the app — this keeps traces, logs and metrics " +
                    "correlated within a single session.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            ConfigField(
                label = "Backend URL",
                inUseValue = ui.backendInUse,
                defaultValue = ui.defaultBackend,
                hintText = "http://192.168.1.100:3333",
                value = backendField,
                onValueChange = { backendField = it },
                keyboardType = KeyboardType.Uri,
            )

            ConfigField(
                label = "OTLP endpoint",
                inUseValue = ui.otlpInUse,
                defaultValue = ui.defaultOtlp,
                hintText = "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp",
                value = otlpField,
                onValueChange = { otlpField = it },
                keyboardType = KeyboardType.Uri,
            )

            ConfigField(
                label = "OTLP instance ID",
                inUseValue = ui.otlpInstanceIdInUse,
                defaultValue = ui.defaultOtlpInstanceId,
                hintText = "1234567",
                value = instanceIdField,
                onValueChange = { instanceIdField = it },
                keyboardType = KeyboardType.Number,
                supportingText = "Numeric ID from your Grafana Cloud OTLP Gateway integration.",
            )

            SecretField(
                label = "OTLP API key",
                inUseValue = ui.otlpApiKeyInUse,
                defaultValue = ui.defaultOtlpApiKey,
                value = apiKeyField,
                onValueChange = { apiKeyField = it },
                supportingText = "Combined with the instance ID to build " +
                    "Authorization: Basic base64(instanceId:apiKey).",
            )

            Button(
                modifier = Modifier.fillMaxWidth(),
                enabled = !ui.saving,
                onClick = {
                    viewModel.save(
                        backendUrl = backendField,
                        otlpEndpoint = otlpField,
                        otlpInstanceId = instanceIdField,
                        otlpApiKey = apiKeyField,
                    )
                },
            ) {
                if (ui.saving) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                } else {
                    Text("Save")
                }
            }

            OutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                enabled = !ui.saving,
                onClick = {
                    viewModel.clear()
                    backendField = ""
                    otlpField = ""
                    instanceIdField = ""
                    apiKeyField = ""
                },
            ) {
                Text("Use defaults (clear overrides)")
            }

            ui.statusMessage?.let { StatusCard(message = it) }
        }
    }
}

@Composable
private fun ConfigField(
    label: String,
    inUseValue: String,
    defaultValue: String,
    hintText: String,
    value: String,
    onValueChange: (String) -> Unit,
    keyboardType: KeyboardType = KeyboardType.Text,
    supportingText: String? = null,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(label, style = MaterialTheme.typography.titleSmall)

            LabelledMonoLine(label = "Currently in use", value = inUseValue.ifEmpty { "(not set)" })
            if (defaultValue != inUseValue) {
                LabelledMonoLine(label = "Default", value = defaultValue.ifEmpty { "(not set)" })
            }

            Spacer(Modifier.height(4.dp))
            OutlinedTextField(
                modifier = Modifier.fillMaxWidth(),
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                label = { Text("Override (empty = use default)") },
                placeholder = { Text(hintText) },
                keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
                supportingText = supportingText?.let { { Text(it) } },
            )
        }
    }
}

@Composable
private fun SecretField(
    label: String,
    inUseValue: String,
    defaultValue: String,
    value: String,
    onValueChange: (String) -> Unit,
    supportingText: String? = null,
) {
    var revealed by rememberSaveable { mutableStateOf(false) }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(label, style = MaterialTheme.typography.titleSmall)

            LabelledMonoLine(label = "Currently in use", value = maskSecret(inUseValue))
            if (defaultValue != inUseValue) {
                LabelledMonoLine(label = "Default", value = maskSecret(defaultValue))
            }

            Spacer(Modifier.height(4.dp))
            OutlinedTextField(
                modifier = Modifier.fillMaxWidth(),
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                label = { Text("Override (empty = use default)") },
                placeholder = { Text("glc_xxxxxxxxxxxx") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                visualTransformation = if (revealed) VisualTransformation.None else PasswordVisualTransformation(),
                trailingIcon = {
                    IconButton(onClick = { revealed = !revealed }) {
                        Icon(
                            imageVector = if (revealed) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                            contentDescription = if (revealed) "Hide API key" else "Show API key",
                        )
                    }
                },
                supportingText = supportingText?.let { { Text(it) } },
            )
        }
    }
}

private fun maskSecret(value: String): String {
    if (value.isEmpty()) return "(not set)"
    // For very short values, don't reveal anything — just bullets.
    if (value.length <= 8) return "•".repeat(value.length.coerceAtLeast(4))
    val head = value.take(4)
    val tail = value.takeLast(4)
    val middleBullets = (value.length - 8).coerceAtMost(8)
    return head + "•".repeat(middleBullets) + tail
}

@Composable
private fun LabelledMonoLine(label: String, value: String) {
    Column {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
        )
    }
}

@Composable
private fun StatusCard(message: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = SuccessContainerCfg),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = SuccessOnContainerCfg)
            Box(Modifier.weight(1f)) { Text(message, color = SuccessOnContainerCfg) }
        }
    }
}

private val SuccessContainerCfg = Color(0xFFE8F5E9)
private val SuccessOnContainerCfg = Color(0xFF1B5E20)
