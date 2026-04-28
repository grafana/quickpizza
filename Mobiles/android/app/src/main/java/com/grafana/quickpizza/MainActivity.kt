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
 * Emits an `app.screen.view` event on every [NavController] destination change.
 *
 * Jetpack Compose Navigation is not yet covered by opentelemetry-android's
 * auto-instrumentation (see open-telemetry/opentelemetry-android#361), so we
 * bridge it manually via [NavController.OnDestinationChangedListener].
 *
 * Uses OTel semconv registered attribute `app.screen.name` for the screen
 * identifier. We avoid `screen.name` because the SDK's ScreenAttributesLogProcessor
 * unconditionally overwrites it with the Activity/Fragment name.
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
                "app.screen.view",
                mapOf(
                    "app.screen.name" to route,
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
