package com.honlnk.md_opener.app.core

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import java.io.File

/**
 * 解析 .md 中引用的相对图片路径（如 ./images/a.png、images/a.png）。
 * - file:// 来源：直接套用父目录拼接。
 * - content:// 来源：仅对树形 DocumentsProvider（如外置存储）生效，
 *   通过 buildChildDocumentsUriUsingTree 枚举同级文件再匹配文件名。
 * 解析不到时返回 null，由前端优雅降级（显示占位）。
 */
object SiblingResolver {

    fun resolve(context: Context, baseUri: Uri, relPath: String): String? {
        val clean = relPath.trimStart('.', '/').replace('\\', '/')
        return try {
            when (baseUri.scheme) {
                "file" -> {
                    val base = baseUri.path ?: return null
                    val parent = File(base).parentFile ?: return null
                    val target = File(parent, clean)
                    if (target.exists()) target.toURI().toString() else null
                }
                "content" -> {
                    val docId = DocumentsContract.getDocumentId(baseUri) ?: return null
                    val slash = docId.lastIndexOf('/')
                    val parentId = if (slash >= 0) docId.substring(0, slash) else docId
                    val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(baseUri, parentId)
                    val name = clean.substringAfterLast('/')
                    context.contentResolver.query(
                        childrenUri,
                        arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, OpenableColumns.DISPLAY_NAME),
                        null, null, null
                    )?.use { c ->
                        val idIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                        val nameIdx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        while (c.moveToNext()) {
                            if (nameIdx >= 0 && c.getString(nameIdx) == name) {
                                val childDocId = c.getString(idIdx)
                                return DocumentsContract.buildDocumentUriUsingTree(
                                    baseUri, "$parentId/$childDocId"
                                ).toString()
                            }
                        }
                    }
                    null
                }
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }
}
