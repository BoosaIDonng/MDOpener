package com.honlnk.md_opener.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewModelScope
import com.honlnk.md_opener.app.MainViewModel
import kotlinx.coroutines.launch

@Composable
fun AppRoot(vm: MainViewModel) {
    val current by vm.currentFile.collectAsState()
    val lastFile by vm.lastFile.collectAsState()
    var showSettings by remember { mutableStateOf(false) }
    val context = LocalContext.current

    val themeMode by vm.settings.themeMode.collectAsState(initial = 0)
    val fontSizeSp by vm.settings.fontSizeSp.collectAsState(initial = 17)
    val maxWidthDp by vm.settings.maxWidthDp.collectAsState(initial = 720)
    val pdfPaperSize by vm.settings.pdfPaperSize.collectAsState(initial = "a4")
    val pdfKeepBackground by vm.settings.pdfKeepBackground.collectAsState(initial = false)
    val pdfAutoOpen by vm.settings.pdfAutoOpen.collectAsState(initial = false)

    val isDark = when (themeMode) {
        0 -> isSystemInDarkTheme()
        2 -> true
        else -> false
    }

    // 系统返回键分级：设置页 → 主页；应用内打开的文档 → 主页；
    // 外部 intent 直接打开的文档不拦截，直接退出 App 回到来源应用
    val cur = current
    BackHandler(enabled = showSettings || (cur != null && !cur.external)) {
        if (showSettings) showSettings = false else vm.closeCurrent()
    }

    if (showSettings) {
        SettingsScreen(
            themeMode = themeMode,
            fontSizeSp = fontSizeSp,
            maxWidthDp = maxWidthDp,
            onThemeChange = { vm.viewModelScope.launch { vm.settings.setThemeMode(it) } },
            onFontChange = { vm.viewModelScope.launch { vm.settings.setFontSize(it) } },
            onWidthChange = { vm.viewModelScope.launch { vm.settings.setMaxWidth(it) } },
            onBack = { showSettings = false }
        )
    } else if (current != null) {
        ViewerScreen(
            file = current!!,
            isDark = isDark,
            fontSizeSp = fontSizeSp,
            maxWidthDp = maxWidthDp,
            pdfPaperSize = pdfPaperSize,
            pdfKeepBackground = pdfKeepBackground,
            pdfAutoOpen = pdfAutoOpen,
            onPdfPaperChange = { vm.viewModelScope.launch { vm.settings.setPdfPaperSize(it) } },
            onPdfKeepBgChange = { vm.viewModelScope.launch { vm.settings.setPdfKeepBackground(it) } },
            onPdfAutoOpenChange = { vm.viewModelScope.launch { vm.settings.setPdfAutoOpen(it) } },
            onClose = vm::closeCurrent
        )
    } else {
        HomeScreen(
            onOpenUri = { vm.openUri(context, it) },
            onSettings = { showSettings = true },
            hasRecent = lastFile != null,
            onOpenRecent = vm::reopenLast
        )
    }
}
