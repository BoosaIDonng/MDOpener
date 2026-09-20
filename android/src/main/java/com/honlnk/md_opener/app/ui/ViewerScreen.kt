package com.honlnk.md_opener.app.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintCallbackFactory
import android.print.PrintDocumentAdapter
import android.print.PrintManager
import android.os.ParcelFileDescriptor
import android.webkit.WebView
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.lazy.items
import com.honlnk.md_opener.app.R
import com.honlnk.md_opener.app.model.OpenedFile
import com.honlnk.md_opener.app.model.PdfPaperSize
import com.honlnk.md_opener.app.model.TocItem
import com.honlnk.md_opener.app.ui.components.CompactTopAppBar
import com.honlnk.md_opener.app.ui.components.MarkdownWebView
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ViewerScreen(
    file: OpenedFile,
    isDark: Boolean,
    fontSizeSp: Int,
    maxWidthDp: Int,
    pdfPaperSize: String,
    pdfKeepBackground: Boolean,
    pdfAutoOpen: Boolean,
    onPdfPaperChange: (String) -> Unit,
    onPdfKeepBgChange: (Boolean) -> Unit,
    onPdfAutoOpenChange: (Boolean) -> Unit,
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val webViewRef = remember { mutableStateOf<WebView?>(null) }
    val toc = remember { mutableStateListOf<TocItem>() }
    var showToc by remember { mutableStateOf(false) }
    var showSearch by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    var searchCount by remember { mutableIntStateOf(0) }
    var showExportDialog by remember { mutableStateOf(false) }

    // 「另存为 .pdf」选择器：选定位置后直接写入，取消则恢复折叠与主题
    val pdfSaver = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/pdf")
    ) { uri ->
        val wv = webViewRef.value
        if (wv == null || uri == null) {
            wv?.evaluateJavascript("window.restoreAfterPrint && window.restoreAfterPrint()", null)
            return@rememberLauncherForActivityResult
        }
        writePdfToFile(
            context, wv, uri, file.name,
            PdfPaperSize.fromId(pdfPaperSize).mediaSize(),
            pdfAutoOpen
        )
    }

    Scaffold(
        topBar = {
            CompactTopAppBar(
                title = file.name,
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
                    }
                },
                actions = {
                    IconButton(onClick = { showSearch = !showSearch }) {
                        Icon(Icons.Filled.Search, stringResource(R.string.search))
                    }
                    IconButton(onClick = { showToc = true }) {
                        Icon(Icons.Filled.List, stringResource(R.string.toc))
                    }
                    IconButton(onClick = { showExportDialog = true }) {
                        Icon(Icons.Filled.PictureAsPdf, stringResource(R.string.export_pdf))
                    }
                }
            )
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            if (showSearch) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { q ->
                        searchQuery = q
                        webViewRef.value?.evaluateJavascript(
                            "window.findText(${JSONObject.quote(q)})"
                        ) { res -> searchCount = res?.toIntOrNull() ?: 0 }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    placeholder = { Text("搜索（${searchCount} 处）") },
                    singleLine = true,
                    trailingIcon = {
                        Text("$searchCount", style = MaterialTheme.typography.labelSmall)
                    }
                )
            }

            when {
                file.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.CircularProgressIndicator()
                }
                file.error -> Box(
                    Modifier.fillMaxSize().padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(stringResource(R.string.read_error), style = MaterialTheme.typography.bodyLarge)
                }
                else -> MarkdownWebView(
                    markdown = file.content ?: "",
                    isDark = isDark,
                    fontSizeSp = fontSizeSp,
                    maxWidthDp = maxWidthDp,
                    baseUri = file.uri,
                    onTocReady = {
                        toc.clear()
                        toc.addAll(it)
                    },
                    onWebViewCreated = { webViewRef.value = it },
                    modifier = Modifier.fillMaxSize()
                )
            }
        }

        if (showExportDialog) {
            // 弹窗内选项每次打开时从持久化设置初始化
            var paper by remember { mutableStateOf(PdfPaperSize.fromId(pdfPaperSize)) }
            var keepBg by remember { mutableStateOf(pdfKeepBackground) }
            var autoOpen by remember { mutableStateOf(pdfAutoOpen) }
            AlertDialog(
                onDismissRequest = { showExportDialog = false },
                title = { Text(stringResource(R.string.export_pdf)) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("纸张大小", style = MaterialTheme.typography.titleSmall)
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            PdfPaperSize.values().forEach { p ->
                                FilterChip(
                                    selected = paper == p,
                                    onClick = { paper = p },
                                    label = { Text(p.label) }
                                )
                            }
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Switch(checked = keepBg, onCheckedChange = { keepBg = it })
                            Spacer(Modifier.width(12.dp))
                            Column {
                                Text("保留背景色")
                                Text(
                                    if (keepBg) "整页铺背景色，适合电子阅读"
                                    else "白底，适合打印（省墨）",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Switch(checked = autoOpen, onCheckedChange = { autoOpen = it })
                            Spacer(Modifier.width(12.dp))
                            Column {
                                Text("自动打开")
                                Text(
                                    "保存成功后立即用 PDF 阅读器打开",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = {
                        onPdfPaperChange(paper.id)
                        onPdfKeepBgChange(keepBg)
                        onPdfAutoOpenChange(autoOpen)
                        showExportDialog = false
                        // 先按选项调整打印态（展开折叠/浅色/背景模式），再弹「另存为」
                        webViewRef.value?.evaluateJavascript(
                            "window.preparePrint && window.preparePrint($keepBg)"
                        ) { pdfSaver.launch(suggestedPdfName(file.name)) }
                    }) { Text("导出") }
                },
                dismissButton = {
                    TextButton(onClick = { showExportDialog = false }) { Text("取消") }
                }
            )
        }

        if (showToc) {
            AlertDialog(
                onDismissRequest = { showToc = false },
                title = { Text(stringResource(R.string.toc)) },
                text = {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 400.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        items(toc) { item ->
                            TextButton(
                                onClick = {
                                    webViewRef.value?.evaluateJavascript(
                                        "window.scrollToHeading('${item.id}')",
                                        null
                                    )
                                    showToc = false
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(
                                    item.text.ifBlank { "(无标题)" },
                                    modifier = Modifier.fillMaxWidth(),
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = if (item.level == 1)
                                        androidx.compose.ui.text.font.FontWeight.Bold
                                    else
                                        androidx.compose.ui.text.font.FontWeight.Normal
                                )
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showToc = false }) { Text("关闭") }
                }
            )
        }
    }
}

/** 导出建议文件名：文档名去扩展名加 .pdf */
private fun suggestedPdfName(fileName: String): String {
    val base = fileName.substringBeforeLast('.', fileName).ifBlank { "document" }
    return "$base.pdf"
}

/** 纸张枚举 → 系统打印纸张规格 */
private fun PdfPaperSize.mediaSize(): PrintAttributes.MediaSize = when (this) {
    PdfPaperSize.A4 -> PrintAttributes.MediaSize.ISO_A4
    PdfPaperSize.A5 -> PrintAttributes.MediaSize.ISO_A5
    PdfPaperSize.B5 -> PrintAttributes.MediaSize.ISO_B5
    PdfPaperSize.LETTER -> PrintAttributes.MediaSize.NA_LETTER
    PdfPaperSize.LEGAL -> PrintAttributes.MediaSize.NA_LEGAL
}

/**
 * 绕开系统打印对话框，直接驱动打印适配器把 PDF 写入用户选择的位置：
 * onLayout（排版）→ onWrite（写入文件描述符）。页边距来自 viewer.html 的 @page 规则。
 * 回调经 android.print 包内的 PrintCallbackFactory 构造（构造函数包私有）；
 * 若运行时拒绝该访问，回退到系统打印对话框。
 */
private fun writePdfToFile(
    context: Context,
    webView: WebView,
    uri: Uri,
    fileName: String,
    mediaSize: PrintAttributes.MediaSize,
    autoOpen: Boolean
) {
    val jobName = fileName.substringBeforeLast('.', fileName).ifBlank { "document" }
    val adapter = webView.createPrintDocumentAdapter(jobName)
    val attributes = PrintAttributes.Builder()
        .setMediaSize(mediaSize)
        .setResolution(PrintAttributes.Resolution("pdf", "pdf", 300, 300))
        .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
        .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
        .build()

    try {
        val layoutCallback = PrintCallbackFactory.layout(
            onFinished = { _, _ ->
                val pfd = try {
                    context.contentResolver.openFileDescriptor(uri, "rw")
                } catch (_: Exception) {
                    null
                }
                if (pfd == null) {
                    adapter.onFinish()
                    finishExport(context, webView, "PDF 保存失败：无法写入所选位置")
                    return@layout
                }
                try {
                    adapter.onWrite(
                        arrayOf(PageRange.ALL_PAGES), pfd, null,
                        PrintCallbackFactory.write(
                            onFinished = { _ ->
                                pfd.close()
                                adapter.onFinish()
                                finishExport(context, webView, "PDF 已保存")
                                if (autoOpen) openPdf(context, uri)
                            },
                            onFailed = { _ ->
                                pfd.close()
                                adapter.onFinish()
                                finishExport(context, webView, "PDF 保存失败")
                            },
                            onCancelled = {
                                pfd.close()
                                adapter.onFinish()
                                finishExport(context, webView, "已取消导出")
                            }
                        )
                    )
                } catch (t: Throwable) {
                    pfd.close()
                    adapter.onFinish()
                    fallbackToPrintDialog(context, webView, jobName)
                }
            },
            onFailed = { _ ->
                adapter.onFinish()
                finishExport(context, webView, "PDF 生成失败")
            },
            onCancelled = {
                adapter.onFinish()
                finishExport(context, webView, "已取消导出")
            }
        )
        adapter.onLayout(null, attributes, null, layoutCallback, null)
    } catch (t: Throwable) {
        fallbackToPrintDialog(context, webView, jobName)
    }
}

/** 直写方案不可用时的回退：走系统打印对话框（用户手动选「保存为 PDF」） */
private fun fallbackToPrintDialog(context: Context, webView: WebView, jobName: String) {
    val printManager = context.getSystemService(Context.PRINT_SERVICE) as PrintManager
    printManager.print(jobName, restoreAfterPrintAdapter(webView, jobName), null)
}

/** 回退方案用的适配器包装：打印结束（含取消）后恢复折叠状态与主题 */
private fun restoreAfterPrintAdapter(webView: WebView, jobName: String): PrintDocumentAdapter {
    val base = webView.createPrintDocumentAdapter(jobName)
    return object : PrintDocumentAdapter() {
        override fun onLayout(
            oldAttributes: PrintAttributes?,
            newAttributes: PrintAttributes,
            cancellationSignal: android.os.CancellationSignal?,
            callback: PrintDocumentAdapter.LayoutResultCallback,
            extras: android.os.Bundle?
        ) = base.onLayout(oldAttributes, newAttributes, cancellationSignal, callback, extras)

        override fun onWrite(
            pages: Array<out PageRange>?,
            destination: ParcelFileDescriptor,
            cancellationSignal: android.os.CancellationSignal?,
            callback: PrintDocumentAdapter.WriteResultCallback
        ) = base.onWrite(pages, destination, cancellationSignal, callback)

        override fun onFinish() {
            base.onFinish()
            webView.post {
                webView.evaluateJavascript("window.restoreAfterPrint && window.restoreAfterPrint()", null)
            }
        }
    }
}

/** 导出收尾：提示结果并恢复折叠状态与主题 */
private fun finishExport(context: Context, webView: WebView, message: String) {
    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    webView.post {
        webView.evaluateJavascript("window.restoreAfterPrint && window.restoreAfterPrint()", null)
    }
}

/** 用系统的 PDF 阅读器打开刚导出的文件 */
private fun openPdf(context: Context, uri: Uri) {
    try {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
    } catch (_: Exception) {
        Toast.makeText(context, "未找到可打开 PDF 的应用", Toast.LENGTH_SHORT).show()
    }
}
