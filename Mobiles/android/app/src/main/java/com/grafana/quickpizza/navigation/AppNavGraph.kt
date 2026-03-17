package com.grafana.quickpizza.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.grafana.quickpizza.features.about.AboutScreen
import com.grafana.quickpizza.features.auth.presentation.LoginScreen
import com.grafana.quickpizza.features.pizza.presentation.HomeScreen
import com.grafana.quickpizza.features.profile.presentation.ProfileScreen

sealed class Screen(val route: String) {
    data object Login : Screen("login")
    data object Home : Screen("home")
    data object Profile : Screen("profile")
    data object About : Screen("about")
}

@Composable
fun AppNavGraph(
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    NavHost(navController = navController, startDestination = Screen.Home.route, modifier = modifier) {
        composable(Screen.Home.route) {
            HomeScreen(
                onNavigateToLogin = { navController.navigate(Screen.Login.route) },
                onNavigateToProfile = { navController.navigate(Screen.Profile.route) },
            )
        }
        composable(Screen.Login.route) {
            LoginScreen(
                onLoginSuccess = { navController.popBackStack() },
                onBack = { navController.popBackStack() },
            )
        }
        composable(Screen.Profile.route) {
            ProfileScreen(
                onBack = { navController.popBackStack() },
                onSignOut = {
                    navController.popBackStack()
                },
            )
        }
        composable(Screen.About.route) {
            AboutScreen(
                onNavigateToLogin = { navController.navigate(Screen.Login.route) },
                onNavigateToProfile = { navController.navigate(Screen.Profile.route) },
            )
        }
    }
}
