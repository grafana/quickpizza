package com.example.otelandroidsample

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import io.opentelemetry.api.common.AttributeKey.longKey
import io.opentelemetry.api.common.AttributeKey.stringKey
import io.opentelemetry.api.common.Attributes
import io.opentelemetry.instrumentation.compose.navigation.withOpenTelemetry
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.Request

// A public demo API. Like every request through OTel.httpClient, it gets a `traceparent` header.
private const val OK_URL = "https://quickpizza.grafana.com/api/quotes"
private const val NOT_FOUND_URL = "https://quickpizza.grafana.com/api/does-not-exist"

// Grafana orange, with matching light tints for the buttons and the status card.
private val SampleColors = lightColorScheme(
    primary = Color(0xFFF46800),
    secondaryContainer = Color(0xFFFFE6D5),
    onSecondaryContainer = Color(0xFF4A1F00),
    surfaceContainerHighest = Color(0xFFF3EFEC),
    background = Color.White,
    surface = Color.White,
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme(colorScheme = SampleColors) { SampleNavHost() }
        }
    }
}

/** Two screens, so you can see Compose navigation arrive as screen views in Frontend Observability. */
@Composable
private fun SampleNavHost() {
    val navController = rememberNavController()
    // Reports every route change ("home", "details") as a screen view. Skipped if OTel did not start.
    OTel.rum?.let { navController.withOpenTelemetry(it) }

    NavHost(navController, startDestination = "home") {
        composable("home") { SampleScreen(onOpenDetails = { navController.navigate("details") }) }
        composable("details") { DetailsScreen(onBack = { navController.popBackStack() }) }
    }
}

/** One button per kind of telemetry. Each action uses the thin `OTel` helpers over the plain OpenTelemetry API. */
@Composable
private fun SampleScreen(onOpenDetails: () -> Unit) {
    var status by remember { mutableStateOf("Tap a button") }
    val scope = rememberCoroutineScope()

    // Network calls must leave the main thread.
    fun runInBackground(work: () -> String) {
        scope.launch { status = withContext(Dispatchers.IO) { work() } }
    }

    Scaffold { padding ->
        LazyColumn(
            Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item { Text("OTel Android Sample", style = MaterialTheme.typography.headlineMedium) }
            item { StatusCard(status) }

            item { SectionTitle("Logs") }
            item { Action("Send info log") { status = sendLog() } }
            item { Action("Send custom event") { status = sendEvent() } }
            item { Action("Report handled error") { status = reportError() } }

            item { SectionTitle("HTTP (automatic spans)") }
            item { Action("GET 200") { runInBackground { get(OK_URL) } } }
            item { Action("GET 404") { runInBackground { get(NOT_FOUND_URL) } } }

            item { SectionTitle("Traces") }
            item { Action("Manual span with child HTTP call") { runInBackground { manualSpan() } } }

            item { SectionTitle("Navigation") }
            item { Action("Open second screen") { onOpenDetails() } }

            item { SectionTitle("Crash") }
            item { Action("Crash the app (reported on next launch)", destructive = true) { crash() } }
        }
    }
}

private fun sendLog(): String {
    OTel.log("Hello from OTel Android", attributes = Attributes.of(stringKey("screen"), "home"))
    return "Log sent"
}

private fun sendEvent(): String {
    OTel.event(
        "add_to_cart",
        Attributes.of(stringKey("item"), "margherita", longKey("quantity"), 2L),
    )
    return "Event sent"
}

private fun reportError(): String {
    try {
        throw CheckoutException("Payment declined")
    } catch (e: CheckoutException) {
        OTel.logException(e)
    }
    return "Error reported"
}

/** Nothing to add here: `OTel.httpClient` creates a client span for the request. */
private fun get(url: String): String = try {
    OTel.httpClient.newCall(Request.Builder().url(url).build()).execute().use { response ->
        "GET ${response.request.url.encodedPath} → ${response.code}"
    }
} catch (e: Exception) {
    "GET $url failed: ${e.message}"
}

/** A manual span. The HTTP call runs inside it, so its span becomes a child. */
private fun manualSpan(): String {
    OTel.span("load_quotes") { span ->
        span.setAttribute("screen", "home")
        get(OK_URL)
    }
    return "Span load_quotes sent"
}

/** An uncaught exception. The agent records it as a crash and sends it on the next launch. */
private fun crash(): Nothing = throw IllegalStateException("Demo crash from the sample app")

/** An example app error. */
class CheckoutException(message: String) : Exception(message)

/** The second screen. Opening it and going back are both reported as screen views. */
@Composable
private fun DetailsScreen(onBack: () -> Unit) {
    Scaffold { padding ->
        LazyColumn(
            Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item { Text("Second screen", style = MaterialTheme.typography.headlineMedium) }
            item { Text("This screen change was sent to Grafana as a screen view named \"details\".") }
            item { Action("Back to home", onClick = onBack) }
        }
    }
}

/** The result of the last tap, and the session ID to search for in Frontend Observability. */
@Composable
private fun StatusCard(status: String) {
    Card(Modifier.fillMaxWidth()) {
        Text(status, Modifier.padding(start = 16.dp, top = 16.dp, end = 16.dp))
        SelectionContainer {
            Text(
                "session.id: ${OTel.sessionId ?: "-"}",
                Modifier.padding(16.dp),
                fontFamily = FontFamily.Monospace,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 12.dp),
    )
}

@Composable
private fun Action(label: String, destructive: Boolean = false, onClick: () -> Unit) {
    val colors = if (destructive) {
        ButtonDefaults.filledTonalButtonColors(
            containerColor = MaterialTheme.colorScheme.errorContainer,
            contentColor = MaterialTheme.colorScheme.onErrorContainer,
        )
    } else {
        ButtonDefaults.filledTonalButtonColors()
    }
    FilledTonalButton(onClick, Modifier.fillMaxWidth(), colors = colors) { Text(label) }
}
