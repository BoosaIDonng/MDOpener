import WebKit

/// mdres:// 请求拦截：viewer.html 把相对图片路径改写为 mdres://<encodeURIComponent(relPath)>，
/// 本 handler 在已授权基准目录（FolderGrantStore 的文件夹授权）下解析并回源。
/// 未授权 / 文件不存在 → 任务失败 → 前端 onerror 降级为 .broken 占位并计数上报。
///
/// 线程模型：start/stop 在主线程；文件读取在后台队列；所有 task 回调切回主线程，
/// 且回调前校验任务未被 stop 取消（对已取消任务回调会令 WKWebView 崩溃）。
final class ImageSchemeHandler: NSObject, WKURLSchemeHandler {

    private(set) var baseDir: URL?
    private var accessing = false
    private var activeTasks = Set<ObjectIdentifier>()
    private let ioQueue = DispatchQueue(label: "mdres.io", qos: .userInitiated)

    /// 切换基准目录（换文档 / 新授权时调用），负责旧作用域的释放
    func updateBase(_ dir: URL?) {
        if accessing, let old = baseDir {
            old.stopAccessingSecurityScopedResource()
            accessing = false
        }
        baseDir = dir
        if let dir {
            accessing = dir.startAccessingSecurityScopedResource()
        }
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let id = ObjectIdentifier(task as AnyObject)
        activeTasks.insert(id)
        let request = task.request
        let base = baseDir
        ioQueue.async { [weak self] in
            let resolved = Self.resolve(request: request, base: base)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.activeTasks.contains(id) else { return }
                if let (data, mime) = resolved {
                    task.didReceive(URLResponse(url: request.url!, mimeType: mime,
                                                expectedContentLength: data.count,
                                                textEncodingName: nil))
                    task.didReceive(data)
                    task.didFinish()
                } else {
                    task.didFailWithError(NSError(domain: "mdres", code: 404,
                                                   userInfo: [NSLocalizedDescriptionKey: "image not resolved"]))
                }
            }
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        activeTasks.remove(ObjectIdentifier(task as AnyObject))
    }

    /// 从绝对串还原相对路径（不能用 url.host/path：host 会被小写化，丢失文件名大小写）
    private static func resolve(request: URLRequest, base: URL?) -> (Data, String)? {
        guard let base, let abs = request.url?.absoluteString,
              abs.hasPrefix("mdres://") else { return nil }
        guard let rel = String(abs.dropFirst("mdres://".count)).removingPercentEncoding else {
            return nil
        }
        let clean = rel.replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "./"))
        guard !clean.isEmpty, !clean.contains("..") else { return nil }
        let target = base.appendingPathComponent(clean)
        guard let data = try? Data(contentsOf: target) else { return nil }
        return (data, mime(forExtension: target.pathExtension))
    }

    private static func mime(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "bmp": return "image/bmp"
        default: return "application/octet-stream"
        }
    }
}
