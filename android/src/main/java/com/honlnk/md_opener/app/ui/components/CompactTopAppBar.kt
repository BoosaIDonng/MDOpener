package com.honlnk.md_opener.app.ui.components

import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

/**
 * 紧凑版 TopAppBar：52dp 高、titleMedium（16sp）标题，
 * 替代默认 64dp / titleLarge（22sp）的标准头栏。
 * statusBarsPadding 放在高度约束之外，保证内容不顶进状态栏。
 *
 * 注意必须用 heightIn(max=) 而非 height()：height() 会把 minHeight 也钉成 52dp，
 * 该约束经 Surface 传入 TopAppBarLayout 的三个槽位（测量时保留 minHeight），
 * 标题槽被迫撑满 52dp 且 Text 顶对齐排字 → 标题视觉上偏上，图标则因
 * IconButton 内部居中而不受影响。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompactTopAppBar(
    title: String,
    navigationIcon: @Composable (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {}
) {
    TopAppBar(
        title = {
            Text(
                title,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.titleMedium
            )
        },
        navigationIcon = navigationIcon ?: {},
        actions = actions,
        modifier = Modifier
            .statusBarsPadding()
            .heightIn(max = 52.dp),
        windowInsets = WindowInsets(0.dp, 0.dp, 0.dp, 0.dp)
    )
}
