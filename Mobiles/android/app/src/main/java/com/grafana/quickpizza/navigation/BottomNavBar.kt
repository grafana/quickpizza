package com.grafana.quickpizza.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import com.grafana.quickpizza.ui.theme.WarmCream
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState

private data class BottomNavItem(
    val screen: Screen,
    val label: String,
    val icon: @Composable () -> Unit,
)

private val bottomNavItems = listOf(
    BottomNavItem(Screen.Home, "Home") { Icon(Icons.Default.Home, contentDescription = "Home") },
    BottomNavItem(Screen.About, "About") { Icon(Icons.Default.Info, contentDescription = "About") },
)

// Routes where the bottom bar should be hidden
private val hiddenRoutes = setOf(Screen.Login.route, Screen.Profile.route)

@Composable
fun BottomNavBar(navController: NavHostController) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    if (currentRoute in hiddenRoutes) return

    NavigationBar(containerColor = WarmCream) {
        bottomNavItems.forEach { item ->
            NavigationBarItem(
                icon = item.icon,
                label = { Text(item.label) },
                selected = currentRoute == item.screen.route,
                onClick = {
                    if (currentRoute != item.screen.route) {
                        navController.navigate(item.screen.route) {
                            popUpTo(navController.graph.startDestinationId) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                },
            )
        }
    }
}
