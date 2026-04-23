package com.grafana.quickpizza

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.navigation.NavController
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import com.grafana.quickpizza.core.o11y.AppEvents
import com.grafana.quickpizza.navigation.AppNavGraph
import com.grafana.quickpizza.navigation.BottomNavBar
import com.grafana.quickpizza.ui.theme.QuickPizzaTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var appEvents: AppEvents

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            QuickPizzaTheme {
                val navController = rememberNavController()
                TrackScreenViews(navController, appEvents)

                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    bottomBar = { BottomNavBar(navController) },
                ) { innerPadding ->
                    val bottomInset = innerPadding.calculateBottomPadding()
                    AppNavGraph(
                        navController = navController,
                        modifier = Modifier
                            .padding(bottom = bottomInset)
                            .consumeWindowInsets(PaddingValues(bottom = bottomInset)),
                    )
                }
            }
        }
    }
}

/**
 * Emits a `screen.view` event on every [NavController] destination change.
 *
 * Jetpack Compose Navigation is not yet covered by opentelemetry-android's
 * auto-instrumentation (see open-telemetry/opentelemetry-android#361), so we
 * bridge it manually via [NavController.OnDestinationChangedListener].
 *
 * Attributes:
 *  - `nav.destination`          — current destination route
 *  - `nav.previous_destination` — route we came from (empty on first event)
 *  - `nav.kind`                 — `initial` | `push` | `pop` | `replace`
 *
 * We deliberately do NOT use the `screen.name` attribute key: the SDK's screen
 * attributes log processor unconditionally overwrites it with the visible
 * Activity/Fragment name (`MainActivity` for this single-Activity app), which
 * silently clobbers anything we set and bumps `dropped_attributes_count`.
 *
 * Consequence: auto-instrumented HTTP/ANR/crash records will still report
 * `screen.name=MainActivity`. Correlate to navigation destinations by
 * timestamp + `session.id`.
 */
@Composable
private fun TrackScreenViews(navController: NavHostController, appEvents: AppEvents) {
    DisposableEffect(navController) {
        var previousRoute: String? = null
        var previousStackSize = 0
        val listener = NavController.OnDestinationChangedListener { controller, destination, _ ->
            val route = destination.route ?: "unknown"
            val currentStackSize = controller.currentBackStack.value.size
            val kind = when {
                previousRoute == null -> "initial"
                currentStackSize > previousStackSize -> "push"
                currentStackSize < previousStackSize -> "pop"
                else -> "replace"
            }
            appEvents.trackEvent(
                "screen.view",
                mapOf(
                    "nav.destination" to route,
                    "nav.previous_destination" to (previousRoute ?: ""),
                    "nav.kind" to kind,
                ),
            )
            previousRoute = route
            previousStackSize = currentStackSize
        }
        navController.addOnDestinationChangedListener(listener)
        onDispose { navController.removeOnDestinationChangedListener(listener) }
    }
}
