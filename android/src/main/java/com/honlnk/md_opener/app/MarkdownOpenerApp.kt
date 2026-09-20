package com.honlnk.md_opener.app

import android.app.Application
import com.honlnk.md_opener.app.core.SettingsRepository

class MarkdownOpenerApp : Application() {
    val settingsRepository: SettingsRepository by lazy { SettingsRepository(this) }
}
