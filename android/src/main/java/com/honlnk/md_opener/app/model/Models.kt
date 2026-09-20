package com.honlnk.md_opener.app.model

import android.net.Uri

data class OpenedFile(
    val uri: Uri?,
    val name: String,
    val content: String?,
    val loading: Boolean = false,
    val error: Boolean = false,
    /** 是否由外部 intent（文件管理器/分享）直接打开；决定系统返回键是退出 App 还是退回主页 */
    val external: Boolean = false
)

data class TocItem(
    val id: String,
    val text: String,
    val level: Int
)

/** PDF 导出纸张大小（id 持久化到 DataStore，映射到 PrintAttributes.MediaSize 在 UI 层做） */
enum class PdfPaperSize(val id: String, val label: String) {
    A4("a4", "A4"),
    A5("a5", "A5"),
    B5("b5", "B5"),
    LETTER("letter", "Letter"),
    LEGAL("legal", "Legal");

    companion object {
        fun fromId(id: String?): PdfPaperSize =
            values().firstOrNull { it.id == id } ?: A4
    }
}
