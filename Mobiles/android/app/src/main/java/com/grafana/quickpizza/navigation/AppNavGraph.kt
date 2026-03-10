package com.grafana.quickpizza.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.grafana.quickpizza.features.about.AboutScreen
import com.grafana.quickpizza.features.auth.presentation.LoginScreen
import com.grafana.quickpizza.features.debug.DebugScreen
import com.grafana.quickpizza.features.pizza.presentation.HomeScreen
import com.grafana.quickpizza.features.profile.presentation.ProfileScreen

sealed class Screen(val route: String) {
    data object Login : Screen("login")
    data object Home : Screen("home")
    data object Profile : Screen("profile")
    data object About : Screen("about")
    data object Debug : Screen("debug")
}

@Composable
fun AppNavGraph(
    navController: NavHostController,
    startDestination: String,
    modifier: Modifier = Modifier,
) {
    NavHost(navController = navController, startDestination = startDestination, modifier = modifier) {
        composable(Screen.Login.route) {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                },
            )
        }
        composable(Screen.Home.route) {
            HomeScreen(
                onLoggedOut = {
                    navController.navigate(Screen.Login.route) {
                        popUpTo(Screen.Home.route) { inclusive = true }
                    }
                },
            )
        }
        composable(Screen.Profile.route) {
            ProfileScreen()
        }
        composable(Screen.About.route) {
            AboutScreen()
        }
        composable(Screen.Debug.route) {
            DebugScreen()
        }
    }
}
