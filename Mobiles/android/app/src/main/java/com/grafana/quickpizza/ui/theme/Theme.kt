package com.grafana.quickpizza.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val OrangeAccent = Color(0xFFFF6B35)
val WarmCream = Color(0xFFFDF3E8)

private val LightColorScheme = lightColorScheme(
    primary = OrangeAccent,
    onPrimary = Color.White,
    secondary = OrangeAccent,
    background = WarmCream,
    surface = WarmCream,
    surfaceVariant = Color(0xFFEEDFD0),
)

@Composable
fun QuickPizzaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        content = content,
    )
}
