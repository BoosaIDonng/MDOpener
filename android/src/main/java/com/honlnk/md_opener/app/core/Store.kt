package com.honlnk.md_opener.app.core

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.settingsDataStore by preferencesDataStore("settings")

class SettingsRepository(private val context: Context) {

    private val ds = context.applicationContext.settingsDataStore
    private val THEME = intPreferencesKey("theme")   // 0 跟随系统 / 1 浅色 / 2 深色
    private val FONT = intPreferencesKey("font")     // 字号 sp
    private val MAXW = intPreferencesKey("maxw")     // 正文最大宽度 dp
    private val PDF_PAPER = stringPreferencesKey("pdf_paper")   // PDF 纸张 a4/a5/b5/letter/legal
    private val PDF_BG = booleanPreferencesKey("pdf_bg")        // PDF 保留背景色
    private val PDF_AUTO_OPEN = booleanPreferencesKey("pdf_auto_open")  // 导出后自动打开

    val themeMode: Flow<Int> = ds.data.map { it[THEME] ?: 0 }
    val fontSizeSp: Flow<Int> = ds.data.map { it[FONT] ?: 17 }
    val maxWidthDp: Flow<Int> = ds.data.map { it[MAXW] ?: 720 }
    val pdfPaperSize: Flow<String> = ds.data.map { it[PDF_PAPER] ?: "a4" }
    val pdfKeepBackground: Flow<Boolean> = ds.data.map { it[PDF_BG] ?: false }
    val pdfAutoOpen: Flow<Boolean> = ds.data.map { it[PDF_AUTO_OPEN] ?: false }

    suspend fun setThemeMode(v: Int) = ds.edit { it[THEME] = v }
    suspend fun setFontSize(v: Int) = ds.edit { it[FONT] = v }
    suspend fun setMaxWidth(v: Int) = ds.edit { it[MAXW] = v }
    suspend fun setPdfPaperSize(v: String) = ds.edit { it[PDF_PAPER] = v }
    suspend fun setPdfKeepBackground(v: Boolean) = ds.edit { it[PDF_BG] = v }
    suspend fun setPdfAutoOpen(v: Boolean) = ds.edit { it[PDF_AUTO_OPEN] = v }
}
