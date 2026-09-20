import UIKit
import WebKit

/// PDF 导出：从 WebView 的打印态（preparePrint 已应用：折叠展开、强制浅色）
/// 提取 HTML，经 UIMarkupTextPrintFormatter 智能分页 + UIGraphicsPDFRenderer 落盘。
/// 对应安卓 PrintManager + createPrintDocumentAdapter 直写方案；
/// `---` 分割线强制分页由 viewer.html 打印 CSS（hr+* break-before）经排版器生效。
enum PdfExporter {

    /// 生成 PDF 并写入临时文件，返回该 URL（随后由导出选择器复制到用户所选位置）。
    /// UIKit 排版须在主线程执行。
    @MainActor
    static func export(webView: WKWebView, keepBackground: Bool, paper: PdfPaperSize,
                       suggestedName: String) async throws -> URL {
        let html = try await webView.evaluateJavaScript(
            "document.documentElement.outerHTML") as? String
        guard let html else {
            throw NSError(domain: "mdopener.pdf", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "无法提取渲染内容"])
        }
        let data = render(html: html, keepBackground: keepBackground, paper: paper)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(suggestedName)
        try data.write(to: url)
        return url
    }

    /// 纸张枚举 → 点尺寸（72dpi）
    static func paperSize(_ paper: PdfPaperSize) -> CGSize {
        switch paper {
        case .a4: return CGSize(width: 595.28, height: 841.89)
        case .a5: return CGSize(width: 419.53, height: 595.28)
        case .b5: return CGSize(width: 498.90, height: 708.66)
        case .letter: return CGSize(width: 612, height: 792)
        case .legal: return CGSize(width: 612, height: 1008)
        }
    }

    private static func render(html: String, keepBackground: Bool, paper: PdfPaperSize) -> Data {
        let size = paperSize(paper)
        let pageRect = CGRect(origin: .zero, size: size)
        // 与 viewer.html @page 视觉对齐：上下 14mm ≈ 39.7pt，左右 12mm ≈ 34pt
        let contentRect = pageRect.insetBy(dx: 34, dy: 39.7)

        let printRenderer = UIPrintPageRenderer()
        printRenderer.addPrintFormatter(
            UIMarkupTextPrintFormatter(markupText: html), startingAtPageAt: 0)
        // paperRect / printableRect 是只读属性，KVC 注入为社区既定用法
        printRenderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        printRenderer.setValue(NSValue(cgRect: contentRect), forKey: "printableRect")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "MD Opener"]
        let pdf = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return pdf.pdfData { ctx in
            for page in 0..<printRenderer.numberOfPages {
                ctx.beginPage()
                if keepBackground {
                    // 整页铺暖纸底色（内容已由 preparePrint 切为浅色打印态），对应安卓 print-keepbg
                    ctx.cgContext.setFillColor(
                        UIColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1).cgColor)
                    ctx.cgContext.fill(pageRect)
                }
                printRenderer.drawPage(at: page, in: contentRect)
            }
        }
    }
}
