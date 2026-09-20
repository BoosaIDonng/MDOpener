import SwiftUI
import WebKit

/// 查看器骨架（②）：加载态 / 错误态 / WebView 渲染 + 标题与返回。
/// TOC、页内搜索、PDF 导出入口在 ④⑤ 接入。
struct ViewerScreen: View {
    let file: OpenedFile
    let onClose: () -> Void

    @Environment(\.colorScheme) private var scheme
    // ④ 接入设置后由持久化设置驱动；默认值与安卓 Store.kt 一致
    private let fontSize = 17
    private let maxWidth = 720

    @State private var webView: WKWebView?
    @State private var toc: [TocItem] = []

    var body: some View {
        content
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
            }
    }

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
                isDark: scheme == .dark,
                fontSize: fontSize,
                maxWidth: maxWidth,
                onTocReady: { toc = $0 },
                onWebViewCreated: { webView = $0 }
            )
            // 换文档时整个 WebView 重建（对应安卓 remember(baseUri) 的桥随文档重建）
            .id(file.id)
        }
    }
}
