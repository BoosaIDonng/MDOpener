@file:Suppress("PackageDirectoryMismatch")

package android.print

/**
 * PrintDocumentAdapter 的两个回调（LayoutResultCallback / WriteResultCallback）
 * 构造函数为 package-private，应用包内无法继承，导致无法脱离系统打印对话框
 * 直接驱动 WebView 打印适配器生成 PDF。
 *
 * 本类放在 android.print 包内以获得同包访问权（社区通行做法）。
 * 注意：部分系统的运行时类加载检查可能拒绝这种跨类加载器的包私有访问，
 * 调用方必须 try-catch 并准备回退方案（系统打印对话框）。
 */
object PrintCallbackFactory {

    fun layout(
        onFinished: (PrintDocumentInfo, Boolean) -> Unit,
        onFailed: (CharSequence?) -> Unit,
        onCancelled: () -> Unit = {}
    ): PrintDocumentAdapter.LayoutResultCallback =
        object : PrintDocumentAdapter.LayoutResultCallback() {
            override fun onLayoutFinished(info: PrintDocumentInfo, changed: Boolean) =
                onFinished(info, changed)

            override fun onLayoutFailed(error: CharSequence?) = onFailed(error)

            override fun onLayoutCancelled() = onCancelled()
        }

    fun write(
        onFinished: (Array<out PageRange>) -> Unit,
        onFailed: (CharSequence?) -> Unit,
        onCancelled: () -> Unit = {}
    ): PrintDocumentAdapter.WriteResultCallback =
        object : PrintDocumentAdapter.WriteResultCallback() {
            override fun onWriteFinished(pages: Array<out PageRange>) = onFinished(pages)

            override fun onWriteFailed(error: CharSequence?) = onFailed(error)

            override fun onWriteCancelled() = onCancelled()
        }
}
