package com.grafana.quickpizza.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val OrangeAccent = Color(0xFFFF6B35)
private val OrangeAccentDark = Color(0xFFFF8C5A)

private val LightColorScheme = lightColorScheme(
    primary = OrangeAccent,
    onPrimary = Color.White,
    secondary = OrangeAccent,
)

private val DarkColorScheme = darkColorScheme(
    primary = OrangeAccentDark,
    onPrimary = Color.Black,
    secondary = OrangeAccentDark,
)

@Composable
fun QuickPizzaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        content = content,
    )
}
