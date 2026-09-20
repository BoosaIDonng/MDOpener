import SwiftUI

/// 应用外壳配色：取值对齐安卓 Theme.kt（源自 typewriter.css 的暖纸 / 深炭双配色），
/// 让工具栏、控件 tint 与 WebView 内容区同一视觉语言。
enum Theme {
    /// 亮色主色 #A65A2E（肉桂棕）
    static let lightAccent = Color(red: 0.651, green: 0.353, blue: 0.180)
    /// 暗色主色 #D6A878（暖金）
    static let darkAccent = Color(red: 0.839, green: 0.659, blue: 0.471)
    /// 亮色底 #FBF8F1（暖纸）
    static let lightBg = Color(red: 0.984, green: 0.973, blue: 0.945)
    /// 暗色底 #1B1916（深炭）
    static let darkBg = Color(red: 0.106, green: 0.098, blue: 0.086)

    /// 屏幕底色：浅色暖纸 / 深色深炭（视图层按系统外观取用）
    static func homeBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBg : lightBg
    }
}
