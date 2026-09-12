package com.honlnk.md_opener.app.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.honlnk.md_opener.app.R
import com.honlnk.md_opener.app.ui.components.CompactTopAppBar

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onOpenUri: (Uri) -> Unit,
    onSettings: () -> Unit,
    hasRecent: Boolean,
    onOpenRecent: () -> Unit
) {
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) onOpenUri(uri)
    }

    Scaffold(
        topBar = {
            CompactTopAppBar(
                title = stringResource(R.string.app_name),
                actions = {
                    // 「最近文档」只在本次运行中关闭过文档后出现，进程结束即清空
                    if (hasRecent) {
                        IconButton(onClick = onOpenRecent) {
                            Icon(Icons.Filled.History, stringResource(R.string.reopen_recent))
                        }
                    }
                    IconButton(onClick = onSettings) {
                        Icon(Icons.Filled.Settings, stringResource(R.string.settings))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // 呼吸动画：空闲时轻微缩放脉冲
            val breathing by rememberInfiniteTransition(label = "breathing").animateFloat(
                initialValue = 1f,
                targetValue = 1.06f,
                animationSpec = infiniteRepeatable(
                    animation = tween(2000),
                    repeatMode = RepeatMode.Reverse
                ),
                label = "breathing"
            )

            // 按压反馈：按下时缩小
            val interactionSource = remember { MutableInteractionSource() }
            val pressed by interactionSource.collectIsPressedAsState()
            val pressScale by animateFloatAsState(
                targetValue = if (pressed) 0.92f else 1f,
                label = "pressScale"
            )

            Surface(
                onClick = { launcher.launch(arrayOf("*/*")) },
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primary,
                interactionSource = interactionSource,
                modifier = Modifier
                    .size(180.dp)
                    .scale(breathing * pressScale)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Filled.Description,
                        contentDescription = stringResource(R.string.open_file),
                        tint = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.size(72.dp)
                    )
                }
            }

            Spacer(Modifier.height(24.dp))
            Text(
                text = stringResource(R.string.home_hint),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
