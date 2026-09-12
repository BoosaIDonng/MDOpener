package com.honlnk.md_opener.app.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.honlnk.md_opener.app.R
import com.honlnk.md_opener.app.ui.components.CompactTopAppBar
import kotlin.math.roundToInt

// 应用保持零联网权限，检查更新通过浏览器跳转实现，不在 App 内请求网络
private const val RELEASES_URL = "https://github.com/honlnk/MDOpener/releases/latest"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    themeMode: Int,
    fontSizeSp: Int,
    maxWidthDp: Int,
    onThemeChange: (Int) -> Unit,
    onFontChange: (Int) -> Unit,
    onWidthChange: (Int) -> Unit,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    // WebView 满屏铺开，其 CSS 视口宽度≈屏幕 dp 宽；max-width ≥ 屏宽时永远不限制排版
    val screenWidthDp = LocalConfiguration.current.screenWidthDp
    val versionName = remember {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull() ?: "?"
    }

    Scaffold(
        topBar = {
            CompactTopAppBar(
                title = stringResource(R.string.settings),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {
            Text("主题", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    stringResource(R.string.theme_system) to 0,
                    stringResource(R.string.theme_light) to 1,
                    stringResource(R.string.theme_dark) to 2
                ).forEach { (label, value) ->
                    FilterChip(
                        selected = themeMode == value,
                        onClick = { onThemeChange(value) },
                        label = { Text(label) }
                    )
                }
            }

            Spacer(Modifier.height(24.dp))
            Text(
                "${stringResource(R.string.font_size)}：${fontSizeSp}sp",
                style = MaterialTheme.typography.titleMedium
            )
            Slider(
                value = fontSizeSp.toFloat(),
                onValueChange = { onFontChange(it.roundToInt()) },
                valueRange = 12f..28f,
                steps = 16
            )

            Spacer(Modifier.height(24.dp))
            Text(
                "${stringResource(R.string.content_width)}：${maxWidthDp}dp",
                style = MaterialTheme.typography.titleMedium
            )
            Slider(
                value = maxWidthDp.toFloat(),
                onValueChange = { onWidthChange(it.roundToInt()) },
                valueRange = 240f..1100f,
                steps = 42
            )
            if (maxWidthDp >= screenWidthDp) {
                Spacer(Modifier.height(4.dp))
                Text(
                    stringResource(R.string.content_width_beyond_screen, screenWidthDp),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(Modifier.height(24.dp))
            Text(stringResource(R.string.check_update), style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(4.dp))
            Text(
                "${stringResource(R.string.current_version)}：v$versionName",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(8.dp))
            TextButton(onClick = {
                runCatching {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(RELEASES_URL)))
                }
            }) {
                Text(stringResource(R.string.view_latest_release))
            }
        }
    }
}
