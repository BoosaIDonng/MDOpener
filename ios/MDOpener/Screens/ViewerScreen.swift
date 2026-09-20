import SwiftUI
import WebKit
import UniformTypeIdentifiers

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
                Button {
                    showToc = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("目录")
            }
        }
        .sheet(isPresented: $showToc) {
            tocSheet
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
                            // id 由 viewer.html 生成（h-N 形态），无注入面
                            webView?.evaluateJavaScript(
                                "window.scrollToHeading && window.scrollToHeading('\(item.id)')",
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
                Text("授权所在文件夹后可显示")
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
        // 已有文件夹授权仍失败 → 文件确实缺失，不打扰
        if FolderGrantStore.load() == nil {
            showImageBanner = true
        }
    }

    private func rerenderImages() {
        webView?.evaluateJavaScript(
            "window.setMarkdown && window.setMarkdown(\((file.content ?? "").jsLiteral));",
            completionHandler: nil)
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
