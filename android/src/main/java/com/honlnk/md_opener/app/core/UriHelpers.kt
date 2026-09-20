package com.honlnk.md_opener.app.core

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

object UriReader {

    /** 通过 ContentResolver 读取文本（兼容 content:// 与 file:// 以及 scoped storage）。
     *  编码策略：BOM 嗅探 → UTF-8 严格解码 → GB18030 回退（覆盖 GBK/GB2312） */
    fun read(context: Context, uri: Uri): String? {
        return try {
            val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: return null
            decodeText(bytes)
        } catch (e: Exception) {
            null
        }
    }

    private fun decodeText(bytes: ByteArray): String {
        // BOM 嗅探
        if (bytes.size >= 3 && bytes[0] == 0xEF.toByte() && bytes[1] == 0xBB.toByte() && bytes[2] == 0xBF.toByte()) {
            return String(bytes, 3, bytes.size - 3, Charsets.UTF_8)
        }
        if (bytes.size >= 2) {
            if (bytes[0] == 0xFE.toByte() && bytes[1] == 0xFF.toByte()) {
                return String(bytes, 2, bytes.size - 2, Charsets.UTF_16BE)
            }
            if (bytes[0] == 0xFF.toByte() && bytes[1] == 0xFE.toByte()) {
                return String(bytes, 2, bytes.size - 2, Charsets.UTF_16LE)
            }
        }
        // 无 BOM：先按 UTF-8 严格解码，非法序列则视为 GBK 系编码
        val utf8Decoder = Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        try {
            return utf8Decoder.decode(ByteBuffer.wrap(bytes)).toString()
        } catch (_: Exception) {
        }
        return String(bytes, charset("GB18030"))
    }

    /** 取得文件显示名 */
    fun displayName(context: Context, uri: Uri): String? {
        if (uri.scheme == "content") {
            val proj = arrayOf(OpenableColumns.DISPLAY_NAME)
            try {
                context.contentResolver.query(uri, proj, null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) return c.getString(idx)
                    }
                }
            } catch (_: Exception) {
            }
        }
        return uri.lastPathSegment
    }
}
