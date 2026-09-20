import SwiftUI
import WebKit

/// WKWebView 封装：加载 bundle 内 web/viewer.html，注入 setMarkdown / applyTheme。
/// 桥接模型：native → JS 用 evaluateJavaScript；JS → native 用 WKScriptMessageHandler
/// （toc / ready 消息）；相对图片走 mdres:// 自定义 scheme（④ 接入 handler）。
/// 页面 ready 前暂缓注入（对应安卓 onPageFinished 后 renderTicket 才生效的语义）。
struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    let isDark: Bool
    let fontSize: Int
    let maxWidth: Int
    let imageHandler: ImageSchemeHandler
    let onTocReady: ([TocItem]) -> Void
    let onImagesFailed: () -> Void
    let onWebViewCreated: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "toc")
        config.userContentController.add(context.coordinator, name: "ready")
        config.userContentController.add(context.coordinator, name: "imgFailed")
        // 相对图片经自定义 scheme 回到原生侧解析（对应安卓 AndroidBridge.resolveImage）
        config.setURLSchemeHandler(imageHandler, forURLScheme: "mdres")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.host = webView
        if let html = Bundle.main.url(forResource: "viewer", withExtension: "html", subdirectory: "web") {
            webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }
        onWebViewCreated(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncIfNeeded()
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // userContentController 强持有 coordinator，显式移除避免常驻
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        coordinator.host = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: MarkdownWebView
        weak var host: WKWebView?
        private var pageReady = false

        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "ready":
                pageReady = true
                // 页面重载后状态清零，重新完整注入一次
                lastMarkdown = nil
                lastThemeDark = nil
                lastThemeFont = nil
                lastThemeWidth = nil
                syncIfNeeded()
            case "toc":
                if let json = message.body as? String,
                   let data = json.data(using: .utf8),
                   let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    parent.onTocReady(arr.compactMap { o in
                        guard let id = o["id"] as? String, let text = o["text"] as? String
                        else { return nil }
                        return TocItem(id: id, text: text, level: o["level"] as? Int ?? 1)
                    })
                }
            case "imgFailed":
                parent.onImagesFailed()
            default:
                break
            }
        }

        /// 仅在内容或主题真正变化时注入，避免 SwiftUI 任意状态刷新触发重渲染
        /// （对应安卓 LaunchedEffect(markdown / theme) 的按 key 生效）
        func syncIfNeeded() {
            guard let host, pageReady else { return }
            let p = parent
            if lastMarkdown != p.markdown {
                lastMarkdown = p.markdown
                host.evaluateJavaScript(
                    "window.setMarkdown && window.setMarkdown(\(p.markdown.jsLiteral));",
                    completionHandler: nil)
            }
            // 元组不遵循 Equatable，T? 与 T 不能直接比较，拆成逐字段判等
            if lastThemeDark != p.isDark || lastThemeFont != p.fontSize || lastThemeWidth != p.maxWidth {
                lastThemeDark = p.isDark
                lastThemeFont = p.fontSize
                lastThemeWidth = p.maxWidth
                host.evaluateJavaScript(
                    "window.applyTheme && window.applyTheme(\(p.isDark), \(p.fontSize), \(p.maxWidth));",
                    completionHandler: nil)
            }
        }

        private var lastMarkdown: String?
        private var lastThemeDark: Bool?
        private var lastThemeFont: Int?
        private var lastThemeWidth: Int?
    }
}

extension String {
    /// 转为可直接内插进 JS 的字符串字面量（含两侧引号）。
    /// 覆盖引号 / 反斜杠 / 控制字符 / 行分隔符，避免文档内容注入时截断脚本。
    var jsLiteral: String {
        var out = "\""
        for scalar in unicodeScalars {
            if scalar == "\"" {
                out += "\\\""
            } else if scalar == "\\" {
                out += "\\\\"
            } else if scalar == "\n" {
                out += "\\n"
            } else if scalar == "\r" {
                out += "\\r"
            } else if scalar == "\t" {
                out += "\\t"
            } else if scalar.value < 0x20 || scalar.value == 0x2028 || scalar.value == 0x2029 {
                out += String(format: "\\u%04x", scalar.value)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }
}
