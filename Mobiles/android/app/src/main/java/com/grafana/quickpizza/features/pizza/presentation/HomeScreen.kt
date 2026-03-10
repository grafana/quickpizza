package com.grafana.quickpizza.features.pizza.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.grafana.quickpizza.features.pizza.presentation.components.CustomizeSection
import com.grafana.quickpizza.features.pizza.presentation.components.PizzaCard
import com.grafana.quickpizza.features.pizza.presentation.components.RatingButtons

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onLoggedOut: () -> Unit,
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("🍕 QuickPizza") },
            actions = {
                if (state.isAuthenticated) {
                    IconButton(onClick = { viewModel.logout(onLoggedOut) }) {
                        Icon(Icons.Default.Logout, contentDescription = "Sign out")
                    }
                }
            },
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Quote banner
            if (state.quote.isNotEmpty()) {
                Text(
                    text = "\"${state.quote}\"",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            // Get pizza button
            Button(
                onClick = { viewModel.getRecommendation() },
                enabled = !state.isLoading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Get Pizza Recommendation")
            }

            // Loading / error / result
            when {
                state.isLoading -> {
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }

                state.errorMessage != null -> {
                    Text(
                        text = state.errorMessage!!,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }

                state.recommendation != null -> {
                    PizzaCard(recommendation = state.recommendation!!)
                    if (!state.ratingSubmitted) {
                        RatingButtons(
                            onLoveIt = { viewModel.ratePizza(stars = 1) },
                            onNoThanks = { viewModel.ratePizza(stars = 0) },
                        )
                    } else {
                        Text(
                            text = "Rating submitted!",
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Customization section
            CustomizeSection(
                restrictions = state.restrictions,
                availableTools = state.availableTools,
                onMaxCaloriesChange = viewModel::updateMaxCalories,
                onVegetarianChange = viewModel::updateVegetarian,
                onCustomNameChange = viewModel::updateCustomName,
                onToolToggle = viewModel::toggleExcludedTool,
            )
        }
    }
}
