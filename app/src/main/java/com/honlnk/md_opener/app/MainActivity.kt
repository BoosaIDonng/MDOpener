package com.honlnk.md_opener.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.core.content.IntentCompat
import androidx.core.view.WindowCompat
import com.honlnk.md_opener.app.ui.AppRoot
import com.honlnk.md_opener.app.ui.theme.MarkdownOpenerTheme

class MainActivity : ComponentActivity() {

    private val vm: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        handleIntent(intent)
        setContent {
            MarkdownOpenerTheme {
                AppRoot(vm)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { vm.openUri(this, it, external = true) }
            Intent.ACTION_SEND -> {
                val uri = IntentCompat.getParcelableExtra(
                    intent, Intent.EXTRA_STREAM, Uri::class.java
                )
                if (uri != null) {
                    vm.openUri(this, uri, external = true)
                } else {
                    // 部分 App（如便签类）只分享纯文本 EXTRA_TEXT，作为内存文档展示
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    if (!text.isNullOrBlank()) vm.openSharedText(text)
                }
            }
        }
    }
}
