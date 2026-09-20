package com.honlnk.md_opener.app.core

import android.content.Context
import android.net.Uri
import android.webkit.JavascriptInterface
import com.honlnk.md_opener.app.model.TocItem
import org.json.JSONArray

class MarkdownJsBridge(
    private val context: Context,
    private val baseUri: Uri?,
    private val onToc: (List<TocItem>) -> Unit
) {

    @JavascriptInterface
    fun resolveImage(relPath: String?): String? {
        if (relPath == null || baseUri == null) return null
        return SiblingResolver.resolve(context, baseUri, relPath)
    }

    @JavascriptInterface
    fun reportToc(json: String?) {
        val items = mutableListOf<TocItem>()
        if (!json.isNullOrBlank()) {
            try {
                val arr = JSONArray(json)
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    items.add(
                        TocItem(
                            id = o.getString("id"),
                            text = o.getString("text"),
                            level = o.optInt("level", 1)
                        )
                    )
                }
            } catch (_: Exception) {
            }
        }
        onToc(items)
    }

    @JavascriptInterface
    fun onReady() {
        // 页面就绪回调（预留）
    }
}
