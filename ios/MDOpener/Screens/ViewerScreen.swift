import SwiftUI
import WebKit
import UniformTypeIdentifiers
import UIKit
import QuickLook

/// 查看器：正文渲染 + 页内搜索（实时命中计数）+ 目录跳转 + 相对图片授权横幅。
/// 行为对齐安卓 ViewerScreen；PDF 导出入口在 ⑤ 接入。
struct ViewerScreen: View {
    let file: OpenedFile
    let isDark: Bool
    @ObservedObject var settings: SettingsStore
    let onClose: () -> Void

    @State private var webView: WKWebView?
    @State private var toc: [TocItem] = []
    @State private var showToc = false
    @State private var showSearch = false
    @State private var query = ""
    @State private var searchCount = 0

    // 相对图片授权横幅：每次打开的文档最多提示一次（对齐计划 §3.3 的非阻断约定）
    @State private var showImageBanner = false
    @State private var bannerShownFor: UUID?
    @State private var showFolderPicker = false
    @State private var imageHandler = ImageSchemeHandler()

    // PDF 导出（对齐安卓：对话框选项 → 打印态 → 落盘 → 选位置保存 → 可选自动打开）
    @State private var showExportDialog = false
    @State private var exportRequested: PdfExportOptions?
    @State private var paper = PdfPaperSize.a4
    @State private var keepBg = false
    @State private var autoOpen = false
    @State private var isExporting = false
    @State private var exportedPdf: ExportedPdf?
    @State private var pendingPreviewUrl: URL?
    @State private var previewUrl: URL?
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if showSearch {
                searchBar
            }
            if showImageBanner {
                imageBanner
            }
            content
        }
        .background(isDark ? Theme.darkBg : Theme.lightBg)
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("返回")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showSearch.toggle()
                    if !showSearch {
                        query = ""
                        applyFind("")
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("搜索")
                .disabled(isExporting || exportRequested != nil)
                Button {
                    showToc = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("目录")
                .disabled(isExporting || exportRequested != nil)
                Button {
                    // 每次打开从持久化设置初始化选项（对齐安卓对话框语义）
                    paper = PdfPaperSize.from(settings.pdfPaper)
                    keepBg = settings.pdfKeepBackground
                    autoOpen = settings.pdfAutoOpen
                    showExportDialog = true
                } label: {
                    Image(systemName: "arrow.up.doc")
                }
                .accessibilityLabel("导出 PDF")
                .disabled(file.loading || file.error || isExporting || exportRequested != nil)
            }
        }
        .sheet(isPresented: $showToc) {
            tocSheet
        }
        .sheet(isPresented: $showExportDialog, onDismiss: {
            guard let options = exportRequested else { return }
            exportRequested = nil
            startExport(options: options)
        }) {
            exportDialog
        }
        .sheet(item: $exportedPdf, onDismiss: {
            if let url = pendingPreviewUrl {
                pendingPreviewUrl = nil
                previewUrl = url
            }
        }) { document in
            ExportPicker(url: document.url) { handleExportDone($0, document: document) }
        }
        .quickLookPreview($previewUrl)
        .overlay(alignment: .bottom) {
            statusOverlay
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView().tint(.white).scaleEffect(1.2)
                }
            }
        }
        // 文件夹授权：授予后解析基准目录生效，重新注入渲染让图片重新走 mdres 解析
        .fileImporter(isPresented: $showFolderPicker,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            FolderGrantStore.save(url)
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
            imageHandler.updateBase(FolderGrantStore.load())
            showImageBanner = false
            bannerShownFor = nil
            rerenderImages()
        }
    }

    // MARK: 搜索（window.findText 返回命中数，实时高亮）

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索（\(searchCount) 处）", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: query) { q in
                    applyFind(q)
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    applyFind("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("清除搜索")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    private func applyFind(_ q: String) {
        webView?.evaluateJavaScript(
            "window.findText && window.findText(\(q.jsLiteral))") { res, _ in
            searchCount = res as? Int ?? 0
        }
    }

    // MARK: 目录

    private var tocSheet: some View {
        NavigationView {
            Group {
                if toc.isEmpty {
                    Text("无标题").foregroundColor(.secondary)
                } else {
                    List(toc) { item in
                        Button {
                            // 原始 HTML 标题可以自带 id，需像搜索词一样转为 JS 字面量。
                            webView?.evaluateJavaScript(
                                "window.scrollToHeading && window.scrollToHeading(\(item.id.jsLiteral))",
                                completionHandler: nil)
                            showToc = false
                        } label: {
                            Text(item.text.isEmpty ? "(无标题)" : item.text)
                                .foregroundColor(.primary)
                                .fontWeight(item.level == 1 ? .bold : .regular)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { showToc = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: 相对图片授权横幅（非阻断）

    private var imageBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("本文档包含相对路径图片")
                    .font(.footnote.weight(.medium))
                Text("请选择文档所在文件夹，并确认图片存在")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("去授权") {
                showFolderPicker = true
            }
            .font(.footnote.weight(.semibold))
            Button {
                showImageBanner = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("关闭横幅")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.10))
    }

    private func handleImagesFailed() {
        guard bannerShownFor != file.id else { return }
        bannerShownFor = file.id
        // 旧授权可能属于另一份文档，仍需提供选择当前文件夹的入口。
        showImageBanner = true
    }

    private func rerenderImages() {
        webView?.evaluateJavaScript(
            "window.setMarkdown && window.setMarkdown(\((file.content ?? "").jsLiteral));",
            completionHandler: { _, error in
                if error == nil, showSearch { applyFind(query) }
            })
    }

    // MARK: PDF 导出

    private var exportDialog: some View {
        NavigationView {
            Form {
                Section("纸张大小") {
                    Picker("纸张", selection: $paper) {
                        ForEach(PdfPaperSize.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Toggle("保留背景色", isOn: $keepBg)
                    Text(keepBg ? "整页保留暖纸背景色，适合电子阅读" : "白底，适合打印（省墨）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Toggle("自动打开", isOn: $autoOpen)
                    Text("保存成功后直接预览 PDF")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("导出 PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showExportDialog = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导出") {
                        exportRequested = PdfExportOptions(paper: paper, keepBackground: keepBg,
                                                           autoOpen: autoOpen)
                        showExportDialog = false
                    }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func startExport(options: PdfExportOptions) {
        guard !isExporting, let wv = webView else { return }
        settings.pdfPaper = options.paper.rawValue
        settings.pdfKeepBackground = options.keepBackground
        settings.pdfAutoOpen = options.autoOpen
        pendingPreviewUrl = nil
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                let url = try await PdfExporter.export(
                    webView: wv, keepBackground: options.keepBackground, paper: options.paper,
                    suggestedName: suggestedPdfName(file.name))
                exportedPdf = ExportedPdf(url: url, options: options)
            } catch {
                statusMessage = "PDF 生成失败：\(error.localizedDescription)"
                flashStatus()
            }
        }
    }

    private func handleExportDone(_ saved: URL?, document: ExportedPdf) {
        if saved != nil {
            statusMessage = "PDF 已保存"
            // 预览本地副本，避免系统选择器关闭后保存位置的访问权限失效。
            pendingPreviewUrl = document.options.autoOpen ? document.url : nil
        } else {
            pendingPreviewUrl = nil
            statusMessage = "已取消导出"
        }
        exportedPdf = nil
        flashStatus()
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if let msg = statusMessage {
            Text(msg)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 24)
        }
    }

    private func flashStatus() {
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            statusMessage = nil
        }
    }

    /// 导出建议文件名：文档名去扩展名加 .pdf（对齐安卓）
    private func suggestedPdfName(_ fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return (base.isEmpty ? "document" : base) + ".pdf"
    }

    // MARK: 正文

    @ViewBuilder
    private var content: some View {
        if file.loading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if file.error {
            Text("文件读取失败")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let md = file.content {
            MarkdownWebView(
                markdown: md,
                isDark: isDark,
                fontSize: settings.fontSize,
                maxWidth: settings.maxWidth,
                imageHandler: imageHandler,
                onTocReady: { toc = $0 },
                onImagesFailed: { handleImagesFailed() },
                onWebViewCreated: { wv in
                    webView = wv
                    // 打开文档即挂载已授权的基准目录（如有）
                    imageHandler.updateBase(FolderGrantStore.load())
                }
            )
            // 换文档时整个 WebView 重建（对应安卓 remember(baseUri) 的桥随文档重建）
            .id(file.id)
        }
    }
}

/// 系统导出选择器（存储到文件 / iCloud 等）；asCopy=true 由系统把临时 PDF 复制到所选位置。
/// 对应安卓 ActivityResultContracts.CreateDocument 的「另存为」语义。
struct ExportPicker: UIViewControllerRepresentable {
    let url: URL
    let onDone: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDone: (URL?) -> Void

        init(_ onDone: @escaping (URL?) -> Void) {
            self.onDone = onDone
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            onDone(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDone(nil)
        }
    }
}
