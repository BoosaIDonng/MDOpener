package com.honlnk.md_opener.app.ui.components

import android.net.Uri
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.honlnk.md_opener.app.core.MarkdownJsBridge
import com.honlnk.md_opener.app.model.TocItem
import org.json.JSONObject

@Composable
fun MarkdownWebView(
    markdown: String,
    isDark: Boolean,
    fontSizeSp: Int,
    maxWidthDp: Int,
    baseUri: Uri?,
    onTocReady: (List<TocItem>) -> Unit,
    onWebViewCreated: (WebView) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val bridge = remember(baseUri) {
        MarkdownJsBridge(context, baseUri, onTocReady)
    }
    val webViewState = remember { mutableStateOf<WebView?>(null) }
    var renderTicket by remember { mutableIntStateOf(0) }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            WebView(ctx).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.allowFileAccess = true
                settings.allowContentAccess = true
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                settings.useWideViewPort = true
                settings.loadWithOverviewMode = true
                addJavascriptInterface(bridge, "AndroidBridge")
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        super.onPageFinished(view, url)
                        renderTicket++
                    }
                }
                loadUrl("file:///android_asset/viewer.html")
                webViewState.value = this
                onWebViewCreated(this)
            }
        }
    )

    LaunchedEffect(markdown, renderTicket) {
        val wv = webViewState.value ?: return@LaunchedEffect
        if (wv.url == null) return@LaunchedEffect
        wv.evaluateJavascript("window.setMarkdown(${JSONObject.quote(markdown)});", null)
    }

    LaunchedEffect(isDark, fontSizeSp, maxWidthDp, renderTicket) {
        val wv = webViewState.value ?: return@LaunchedEffect
        if (wv.url == null) return@LaunchedEffect
        wv.evaluateJavascript(
            "window.applyTheme($isDark, $fontSizeSp, $maxWidthDp);",
            null
        )
    }
}
