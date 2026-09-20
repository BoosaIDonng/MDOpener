package com.honlnk.md_opener.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/*
 * 配色取自 assets/typewriter.css 的设计变量（暖纸 / 深炭），
 * 让应用外壳（工具栏、按钮、弹窗）与 WebView 内容区同一视觉语言：
 * 亮色 = 暖纸米底 + 棕橙主色；暗色 = 深炭底 + 暖金主色。
 */

private val WarmPaper = Color(0xFFFBF8F1)   // --tw-bg（亮）
private val InkText = Color(0xFF33302A)     // --tw-text
private val InkSoft = Color(0xFF6A655A)     // --tw-text-soft
private val Cinnamon = Color(0xFFA65A2E)    // --tw-link（亮）主色
private val GoldTan = Color(0xFFD6A878)     // --tw-link（暗）主色
private val Charcoal = Color(0xFF1B1916)    // --tw-bg（暗）
private val CharcoalText = Color(0xFFD9D3C4)// --tw-text（暗）

private val Light = lightColorScheme(
    primary = Cinnamon,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFF1EBDD),      // --tw-code-bg
    onPrimaryContainer = Color(0xFF5B4636),    // --tw-code-text
    secondary = Color(0xFF8A6A3B),             // --tw-tag-text
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFEFE7D6),    // --tw-tag-bg
    onSecondaryContainer = Color(0xFF4A3A20),
    tertiary = Color(0xFF5C5648),              // --tw-quote-text
    tertiaryContainer = Color(0xFFF1EBDD),
    onTertiaryContainer = Color(0xFF40382B),
    background = WarmPaper,
    onBackground = InkText,
    surface = WarmPaper,
    onSurface = InkText,
    surfaceVariant = Color(0xFFF1EBDD),
    onSurfaceVariant = InkSoft,
    outline = Color(0xFFC9BBA0),               // --tw-quote-border
    outlineVariant = Color(0xFFE0D8C6),        // --tw-rule
    error = Color(0xFFB3402E),
    onError = Color.White,
    errorContainer = Color(0xFFF8DAD3),
    onErrorContainer = Color(0xFF5C1F14),
    inverseSurface = Color(0xFF2B2820),
    inverseOnSurface = Color(0xFFF5F0E5),
    inversePrimary = GoldTan
)

private val Dark = darkColorScheme(
    primary = GoldTan,
    onPrimary = Color(0xFF3A2410),
    primaryContainer = Color(0xFF4A331B),
    onPrimaryContainer = Color(0xFFF1DCBE),
    secondary = Color(0xFFC7A877),             // --tw-tag-text（暗）
    onSecondary = Color(0xFF33240F),
    secondaryContainer = Color(0xFF38332A),    // --tw-border（暗）
    onSecondaryContainer = Color(0xFFE7E0D0),
    tertiary = Color(0xFFB0A792),
    tertiaryContainer = Color(0xFF26221C),     // --tw-code-bg（暗）
    onTertiaryContainer = Color(0xFFE0C9A6),   // --tw-code-text（暗）
    background = Charcoal,
    onBackground = CharcoalText,
    surface = Charcoal,
    onSurface = CharcoalText,
    surfaceVariant = Color(0xFF26221C),
    onSurfaceVariant = Color(0xFFA89F8C),      // --tw-quote-text（暗）
    outline = Color(0xFF4A4438),               // --tw-quote-border（暗）
    outlineVariant = Color(0xFF322D25),        // --tw-rule（暗）
    error = Color(0xFFE08474),
    onError = Color(0xFF2A0B06),
    errorContainer = Color(0xFF5C2620),
    onErrorContainer = Color(0xFFF5DBD5),
    inverseSurface = Color(0xFFF5F0E5),
    inverseOnSurface = Color(0xFF2B2820),
    inversePrimary = Cinnamon
)

@Composable
fun MarkdownOpenerTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) Dark else Light,
        content = content
    )
}
