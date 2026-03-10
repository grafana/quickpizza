package com.grafana.quickpizza

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.ui.Modifier
import androidx.navigation.compose.rememberNavController
import com.grafana.quickpizza.core.storage.TokenStorage
import com.grafana.quickpizza.navigation.AppNavGraph
import com.grafana.quickpizza.navigation.BottomNavBar
import com.grafana.quickpizza.navigation.Screen
import com.grafana.quickpizza.ui.theme.QuickPizzaTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject
    lateinit var tokenStorage: TokenStorage

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            QuickPizzaTheme {
                val navController = rememberNavController()
                val startDestination = if (tokenStorage.token != null) {
                    Screen.Home.route
                } else {
                    Screen.Login.route
                }

                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    bottomBar = { BottomNavBar(navController) },
                ) { innerPadding ->
                    AppNavGraph(
                        navController = navController,
                        startDestination = startDestination,
                        modifier = Modifier.padding(innerPadding),
                    )
                }
            }
        }
    }
}
