package com.honlnk.md_opener.app

import android.app.Application
import android.content.Context
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.honlnk.md_opener.app.core.SettingsRepository
import com.honlnk.md_opener.app.core.UriReader
import com.honlnk.md_opener.app.model.OpenedFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainViewModel(application: Application) : AndroidViewModel(application) {

    private val app = application as MarkdownOpenerApp
    val settings: SettingsRepository = app.settingsRepository

    val currentFile = MutableStateFlow<OpenedFile?>(null)

    /** 最近成功打开的文档（仅内存，随 ViewModel 销毁即失效），供主页一键重开 */
    val lastFile = MutableStateFlow<OpenedFile?>(null)

    fun openUri(context: Context, uri: Uri, external: Boolean = false) {
        val name = UriReader.displayName(context, uri) ?: uri.lastPathSegment ?: "document.md"
        currentFile.value = OpenedFile(uri, name, null, loading = true, external = external)
        viewModelScope.launch(Dispatchers.IO) {
            val content = UriReader.read(context, uri)
            withContext(Dispatchers.Main) {
                if (content != null) {
                    currentFile.value = OpenedFile(uri, name, content, loading = false, external = external)
                } else {
                    currentFile.value = OpenedFile(uri, name, null, loading = false, error = true, external = external)
                }
            }
        }
    }

    /** 接收 ACTION_SEND 的 EXTRA_TEXT 纯文本（无 uri，作为内存文档直接展示） */
    fun openSharedText(text: String) {
        currentFile.value = OpenedFile(null, "shared.md", text, loading = false, external = true)
    }

    fun closeCurrent() {
        // 只记录成功读出内容的文档；读取失败的重开只会再次报错，没有记忆价值
        currentFile.value?.takeIf { it.content != null }?.let { lastFile.value = it }
        currentFile.value = null
    }

    /** 从主页重开最近文档：视为应用内打开，系统返回键退回主页而非退出 App */
    fun reopenLast() {
        lastFile.value?.let { currentFile.value = it.copy(external = false) }
    }
}
