// macOS WebKit 回归检查；直接编译生产 PdfExporter，不需要 Xcode 或第三方依赖。
import AppKit
import PDFKit
import WebKit

@main
@MainActor
struct PdfExportCheck {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            do {
                try await Check().run()
                print("PASS: PDF text, images, paper sizes, pagination and state restoration")
                exit(0)
            } catch {
                fputs("FAIL: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }
}

@MainActor
private final class Check: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var navigation: CheckedContinuation<Void, Error>?

    func run() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='160' height='80'><rect width='160' height='80' fill='#ff0000'/></svg>"
        try svg.write(to: output.appendingPathComponent("image.svg"), atomically: true, encoding: .utf8)
        let handler = ImageSchemeHandler()
        handler.updateBase(output)
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: "mdres")
        for name in ["ready", "toc", "imgFailed"] {
            config.userContentController.add(self, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), configuration: config)
        let window = NSWindow(contentRect: webView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = webView
        window.orderBack(nil)
        defer { window.orderOut(nil) }
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            navigation = continuation
            webView.loadFileURL(root.appendingPathComponent("web/viewer.html"),
                                allowingReadAccessTo: root.appendingPathComponent("web"))
        }
        try await checkCore(webView: webView, handler: handler, output: output, root: root)
        let paragraphs = (1...50).map {
            "PARA\(String(format: "%03d", $0)) Markdown PDF line check. 中文导出测试。 " +
            String(repeating: "A longer paragraph wraps across several lines. ", count: 3)
        }.joined(separator: "\n\n")
        let markdown = """
        # FIRSTMARKER

        正文和代码样式应保留，文字可选择。

        ![local image](image.svg)

        ![encoded image](Space%20%E5%9B%BE.svg?version=1#icon)

        ![uppercase image](UPPER.svg)

        > [!NOTE]- Folded
        > FOLDEDMARKER must be included in the PDF.

        ```swift
        let answer = 42
        ```

        \(paragraphs)

        ---

        # FORCEDMARKER

        LASTMARKER
        """
        let literal = String(data: try JSONSerialization.data(withJSONObject: markdown, options: .fragmentsAllowed),
                             encoding: .utf8)!
        _ = try await webView.evaluateJavaScript("window.setMarkdown(\(literal)); window.applyTheme(true, 17, 720); window.scrollTo(0, 200);")
        let before = try await webView.evaluateJavaScript(stateScript) as! String
        for paper in PdfPaperSize.allCases {
            let url = try await PdfExporter.export(webView: webView, keepBackground: paper == .a5,
                                                   paper: paper, suggestedName: "check.pdf")
            guard let pdf = PDFDocument(url: url), pdf.pageCount > 1 else { throw fail("empty PDF: \(paper)") }
            let saved = output.appendingPathComponent("\(paper.rawValue).pdf")
            try FileManager.default.copyItem(at: url, to: saved)
            print("PDF: \(saved.path)")
            let text = pdf.string ?? ""
            for marker in ["FIRSTMARKER", "FOLDEDMARKER", "FORCEDMARKER", "LASTMARKER"] {
                guard text.contains(marker) else { throw fail("missing \(marker): \(paper), text: \(text.prefix(500))") }
            }
            for index in 1...50 {
                let marker = "PARA\(String(format: "%03d", index))"
                guard text.components(separatedBy: marker).count == 2 else {
                    throw fail("missing or duplicated paragraph \(marker): \(paper)")
                }
            }
            let normalized = normalize(text)
            for paragraph in paragraphs.components(separatedBy: "\n\n") {
                guard normalized.contains(normalize(paragraph)) else { throw fail("clipped paragraph: \(paper)") }
            }
            let thumbnail = pdf.page(at: 0)!.thumbnail(of: CGSize(width: 600, height: 900), for: .mediaBox)
            let bitmap = NSBitmapImageRep(data: thumbnail.tiffRepresentation!)!
            guard let corner = bitmap.colorAt(x: 10, y: 10)?.usingColorSpace(.sRGB) else {
                throw fail("cannot read PDF background: \(paper)")
            }
            let hasWarmBackground = corner.redComponent - corner.blueComponent > 0.01
            guard hasWarmBackground == (paper == .a5) else {
                throw fail("PDF background option ignored: \(paper), \(corner)")
            }
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(paper.rawValue)-thumb.png"))
            var redPixels = 0
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                    if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                       color.redComponent > 0.8, color.greenComponent < 0.4, color.blueComponent < 0.3 {
                        redPixels += 1
                    }
                }
            }
            guard redPixels > 50 else { throw fail("mdres image missing: \(paper), red pixels \(redPixels)") }
            guard pdf.page(at: pdf.pageCount - 1)?.string?.contains("FORCEDMARKER") == true else {
                throw fail("forced page break lost: \(paper)")
            }
            let expected = PdfExporter.paperSize(paper)
            for index in 0..<pdf.pageCount {
                let bounds = pdf.page(at: index)!.bounds(for: .mediaBox)
                guard abs(bounds.width - expected.width) < 0.1, abs(bounds.height - expected.height) < 0.1 else {
                    throw fail("wrong paper size: \(paper)")
                }
            }
            let after = try await webView.evaluateJavaScript(stateScript) as! String
            guard before == after else { throw fail("reading state not restored: \(before) -> \(after)") }
            let imagesLoaded = try await webView.evaluateJavaScript(
                "Array.from(document.images).every(img => img.complete && img.naturalWidth === 160)") as? Bool
            guard imagesLoaded == true else { throw fail("WebKit image URL integration: \(paper)") }
            print("PASS \(paper.rawValue): \(pdf.pageCount) pages, \(text.count) characters")
        }
        // 在打印态布局期间制造异常，确保失败也恢复主题、折叠、宽度和滚动位置。
        _ = try await webView.evaluateJavaScript("document.getElementById('content').getBoundingClientRect = () => { throw new Error('layout-check'); }; void 0;")
        do {
            _ = try await PdfExporter.export(webView: webView, keepBackground: false,
                                             paper: .a4, suggestedName: "failure.pdf")
            throw fail("layout failure was silently accepted")
        } catch let error as NSError where error.domain == WKError.errorDomain {
            let after = try await webView.evaluateJavaScript(stateScript) as! String
            guard before == after else { throw fail("state not restored after failure") }
        }
        let ranges = PdfExporter.pageRanges(height: 250, pageHeight: 100,
                                            forcedBreaks: [0, 80, 80, 250], avoidBreaks: [90..<110])
        guard ranges == [0..<80, 80..<180, 180..<250] else { throw fail("unexpected page ranges: \(ranges)") }
        _ = try await webView.evaluateJavaScript("delete document.getElementById('content').getBoundingClientRect;")
        let codeLines = (1...160).map { "CODE\($0) = \"a line of code\"" }
        let tableRows = (1...80).map { "| ROW\($0) | table content |" }
        let longParagraph = (1...200).map { "WORD\($0)" }.joined(separator: " ")
        let edgeCases: [(String, String, [String])] = [
            ("short", "# SHORTMARKER\n\n中文短文。", ["SHORTMARKER"]),
            ("long-code", "```swift\n" + codeLines.joined(separator: "\n") + "\n```", codeLines),
            ("long-table", "| Key | Value |\n| --- | --- |\n" + tableRows.joined(separator: "\n") +
             "\n\n" + longParagraph, (1...80).map { "ROW\($0)" } + [longParagraph])
        ]
        for (name, markdown, expected) in edgeCases {
            let literal = String(data: try JSONSerialization.data(withJSONObject: markdown, options: .fragmentsAllowed),
                                 encoding: .utf8)!
            _ = try await webView.evaluateJavaScript("window.setMarkdown(\(literal));")
            let url = try await PdfExporter.export(webView: webView, keepBackground: false,
                                                   paper: .a4, suggestedName: "\(name).pdf")
            guard let pdf = PDFDocument(url: url), pdf.pageCount > 0,
                  name != "short" || pdf.pageCount == 1 else { throw fail("empty or wrong page count: \(name)") }
            let text = normalize(pdf.string ?? "")
            for value in expected {
                guard text.contains(normalize(value)) else { throw fail("clipped PDF content: \(name), \(value.prefix(60))") }
            }
            try FileManager.default.copyItem(at: url, to: output.appendingPathComponent("\(name).pdf"))
            print("PASS \(name): \(pdf.pageCount) pages")
        }
    }

    private let stateScript = """
    JSON.stringify({dark: document.body.classList.contains('theme-dark'),
      folded: !document.querySelector('details').open,
      width: document.getElementById('content').style.maxWidth,
      scroll: window.scrollY, style: !!document.getElementById('ios-pdf-style'),
      exporting: document.documentElement.classList.contains('ios-pdf-export')})
    """

    private func fail(_ message: String) -> NSError {
        NSError(domain: "pdf-check", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func normalize(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    private func checkCore(webView: WKWebView, handler: ImageSchemeHandler, output: URL, root: URL) async throws {
        var failures: [String] = []
        func expect(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message); print("FAIL: \(message)") }
        }
        let plain = "中文 Markdown"
        expect(DocumentLoader.decode(Data(plain.utf8)) == plain, "UTF-8 decode")
        expect(DocumentLoader.decode(Data([0xef, 0xbb, 0xbf]) + Data(plain.utf8)) == plain, "UTF-8 BOM")
        expect(DocumentLoader.decode(Data([0xff, 0xfe]) + plain.data(using: .utf16LittleEndian)!) == plain, "UTF-16 LE")
        expect(DocumentLoader.decode(Data([0xfe, 0xff]) + plain.data(using: .utf16BigEndian)!) == plain, "UTF-16 BE")
        let gbk = try Data(contentsOf: root.appendingPathComponent("test/fixtures/gbk-sample.md"))
        expect(DocumentLoader.decode(gbk)?.contains("中文") == true, "GB18030 fixture")
        expect(DocumentLoader.decode(Data()) == "", "empty Markdown")

        let file = output.appendingPathComponent("model.md")
        try "original".write(to: file, atomically: true, encoding: .utf8)
        let model = AppModel()
        model.openUrl(file)
        // 模拟同一 URL 已经进入下一次打开：旧异步读取不能覆盖新一代文档状态。
        let newer = OpenedFile(url: file, name: "model.md", content: "newer")
        model.currentFile = newer
        try await Task.sleep(nanoseconds: 150_000_000)
        expect(model.currentFile?.id == newer.id && model.currentFile?.content == "newer",
               "stale read overwrote a newer document at the same URL")
        model.closeCurrent()
        model.openUrl(output.appendingPathComponent("missing.md"))
        try await Task.sleep(nanoseconds: 150_000_000)
        expect(model.currentFile?.error == true, "missing document error")
        model.closeCurrent()
        expect(model.lastFile?.content != nil, "failed document replaced recent document")

        let bytes = try Data(contentsOf: output.appendingPathComponent("image.svg"))
        try bytes.write(to: output.appendingPathComponent("Space 图.svg"))
        try bytes.write(to: output.appendingPathComponent("UPPER.svg"))
        try bytes.write(to: output.appendingPathComponent("100%.svg"))
        try bytes.write(to: output.appendingPathComponent("Hash#Question?.svg"))
        try bytes.write(to: output.appendingPathComponent("literal%20.svg"))
        for reference in ["./image.svg", "UPPER.svg", "Space%20%E5%9B%BE.svg", "image.svg?version=1#icon",
                          "100%.svg", "100%25.svg", "Hash%23Question%3F.svg", "literal%2520.svg"] {
            let loaded = await requestImage(reference, handler: handler, webView: webView)
            expect(loaded == bytes, "relative image not resolved: \(reference)")
        }
        let outside = output.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".svg")
        try bytes.write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(at: output.appendingPathComponent("escape.svg"),
                                                   withDestinationURL: outside)
        let escaped = await requestImage("escape.svg", handler: handler, webView: webView)
        expect(escaped == nil, "image symlink escaped the granted directory")
        for reference in ["../image.svg", "%2E%2E/image.svg", "/image.svg", "image.svg%00"] {
            let loaded = await requestImage(reference, handler: handler, webView: webView)
            expect(loaded == nil, "unsafe image path accepted: \(reference)")
        }
        let cancelled = SchemeTask(url: schemeURL("image.svg")) { _ in }
        handler.webView(webView, start: cancelled)
        handler.webView(webView, stop: cancelled)
        try await Task.sleep(nanoseconds: 50_000_000)
        expect(!cancelled.finished, "cancelled scheme task received a callback")
        if !failures.isEmpty { throw fail(failures.joined(separator: "; ")) }
        print("PASS: encodings, stale document reads, image URLs, directory boundary and request cancellation")
    }

    private func schemeURL(_ reference: String) -> URL {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.!~*'()"))
        return URL(string: "mdres://" + reference.addingPercentEncoding(withAllowedCharacters: safe)!)!
    }

    private func requestImage(_ reference: String, handler: ImageSchemeHandler, webView: WKWebView) async -> Data? {
        await withCheckedContinuation { continuation in
            let task = SchemeTask(url: schemeURL(reference)) { continuation.resume(returning: $0) }
            handler.webView(webView, start: task)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.navigation?.resume()
        self.navigation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.navigation?.resume(throwing: error)
        self.navigation = nil
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}

private final class SchemeTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    private var data = Data()
    private let completion: (Data?) -> Void
    private(set) var finished = false

    init(url: URL, completion: @escaping (Data?) -> Void) {
        request = URLRequest(url: url)
        self.completion = completion
    }
    func didReceive(_ response: URLResponse) {}
    func didReceive(_ data: Data) { self.data.append(data) }
    func didFinish() { finished = true; completion(data) }
    func didFailWithError(_ error: Error) { finished = true; completion(nil) }
}
