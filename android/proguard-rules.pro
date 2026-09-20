# 保留 WebView 的 JS 桥接类（R8 可能误删）
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.honlnk.md_opener.app.core.MarkdownJsBridge { *; }

# DataStore / androidx 相关
-dontwarn androidx.databinding.**
-dontwarn org.jetbrains.**
