package com.grafana.quickpizza.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalPizza
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.grafana.quickpizza.ui.theme.OrangeAccent

@Composable
fun ProfileAvatarButton(
    isAuthenticated: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    androidx.compose.foundation.layout.Box(
        modifier = modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(if (isAuthenticated) OrangeAccent else Color(0xFFBDBDBD))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = if (isAuthenticated) Icons.Filled.Person else Icons.Outlined.Person,
            contentDescription = "Profile",
            tint = Color.White,
            modifier = Modifier.size(20.dp),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickPizzaTopBar(
    isAuthenticated: Boolean,
    onAvatarClick: () -> Unit,
) {
    TopAppBar(
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Filled.LocalPizza,
                    contentDescription = null,
                    tint = Color(0xFFCC2200),
                    modifier = Modifier.size(28.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "QuickPizza",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFFCC2200),
                )
            }
        },
        actions = {
            ProfileAvatarButton(
                isAuthenticated = isAuthenticated,
                onClick = onAvatarClick,
                modifier = Modifier.padding(end = 8.dp),
            )
        },
        colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.White),
    )
}
