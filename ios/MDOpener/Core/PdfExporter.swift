import CoreGraphics
import Foundation
import WebKit

/// 从正在显示的 WKWebView 导出，保留 bundle 样式、代码高亮和 mdres:// 图片。
/// createPDF 使用屏幕样式，导出布局只在 iOS 临时注入，不改变双端共享的 viewer.html。
enum PdfExporter {

    @MainActor
    static func export(webView: WKWebView, keepBackground: Bool, paper: PdfPaperSize,
                       suggestedName: String) async throws -> URL {
        var pageRect = CGRect(origin: .zero, size: paperSize(paper))
        // 上下 14mm，左右 12mm；按实际可打印宽度重排，避免沿用手机屏宽。
        let contentRect = pageRect.insetBy(dx: 34, dy: 39.7)
        do {
            guard let layout = try await webView.callAsyncJavaScript(
                prepareScript,
                arguments: ["width": Double(contentRect.width), "keepBackground": keepBackground],
                in: nil, contentWorld: .page) as? [String: Any],
                  let height = layout["height"] as? Double,
                  height.isFinite, height > 0 else {
                throw failure("无法取得文档布局，请等待文档加载完成后重试")
            }
            let forced = (layout["breaks"] as? [Double] ?? []).map { CGFloat($0) }
            let avoid = (layout["avoid"] as? [[Double]] ?? []).compactMap { pair -> Range<CGFloat>? in
                guard pair.count == 2, pair[0].isFinite, pair[1].isFinite,
                      pair[1] > pair[0] else { return nil }
                return CGFloat(pair[0])..<CGFloat(pair[1])
            }
            let pages = pageRanges(height: CGFloat(height), pageHeight: contentRect.height,
                                   forcedBreaks: forced, avoidBreaks: avoid)
            let data = NSMutableData()
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &pageRect,
                                          [kCGPDFContextTitle as String: "MD Opener"] as CFDictionary)
            else { throw failure("无法创建 PDF") }
            // 每页单独捕获，避免长文档生成一张超高的中间 PDF。
            for range in pages {
                let sliceHeight = range.upperBound - range.lowerBound
                let config = WKPDFConfiguration()
                config.rect = CGRect(x: 0, y: range.lowerBound,
                                     width: contentRect.width, height: sliceHeight)
                let snapshot = try await webView.pdf(configuration: config)
                guard let provider = CGDataProvider(data: snapshot as CFData),
                      let document = CGPDFDocument(provider), document.numberOfPages == 1,
                      let page = document.page(at: 1),
                      !page.getBoxRect(.mediaBox).isEmpty else {
                    throw failure("WebView 未生成有效的 PDF 页面")
                }
                context.beginPDFPage(nil)
                context.setFillColor(keepBackground
                    ? CGColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1)
                    : CGColor(gray: 1, alpha: 1))
                context.fill(pageRect)
                context.saveGState()
                let target = CGRect(x: contentRect.minX,
                                    y: contentRect.maxY - sliceHeight,
                                    width: contentRect.width, height: sliceHeight)
                context.clip(to: target)
                context.concatenate(page.getDrawingTransform(.mediaBox, rect: target,
                                                              rotate: 0, preserveAspectRatio: true))
                context.drawPDFPage(page)
                context.restoreGState()
                context.endPDFPage()
            }
            context.closePDF()
            guard let provider = CGDataProvider(data: data as CFData),
                  let result = CGPDFDocument(provider), result.numberOfPages == pages.count,
                  result.numberOfPages > 0 else { throw failure("PDF 生成为空，请重试") }

            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(suggestedName)
            try (data as Data).write(to: url, options: .atomic)
            _ = try? await webView.evaluateJavaScript(restoreScript)
            return url
        } catch {
            _ = try? await webView.evaluateJavaScript(restoreScript)
            throw error
        }
    }

    static func paperSize(_ paper: PdfPaperSize) -> CGSize {
        switch paper {
        case .a4: return CGSize(width: 595.28, height: 841.89)
        case .a5: return CGSize(width: 419.53, height: 595.28)
        case .b5: return CGSize(width: 498.90, height: 708.66)
        case .letter: return CGSize(width: 612, height: 792)
        case .legal: return CGSize(width: 612, height: 1008)
        }
    }

    /// 优先在 --- 处换页，其余分页避开文字行与能完整放入一页的块元素。
    static func pageRanges(height: CGFloat, pageHeight: CGFloat, forcedBreaks: [CGFloat],
                           avoidBreaks: [Range<CGFloat>]) -> [Range<CGFloat>] {
        var pages: [Range<CGFloat>] = []
        var start: CGFloat = 0
        let forced = forcedBreaks.filter { $0.isFinite && $0 > 0 && $0 < height }.sorted()
        while start < height {
            var end = min(start + pageHeight, height)
            if let hardBreak = forced.first(where: { $0 > start + 0.5 && $0 <= end }) {
                end = hardBreak
            }
            while let crossing = avoidBreaks.first(where: {
                $0.lowerBound > start + 0.5 && $0.lowerBound < end && $0.upperBound > end
                    && $0.upperBound - $0.lowerBound <= pageHeight
            }) {
                end = crossing.lowerBound
            }
            pages.append(start..<end)
            start = end
        }
        return pages
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "mdopener.pdf", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static let prepareScript = #"""
    const content = document.getElementById('content');
    if (!content || !content.innerHTML.trim() || typeof window.preparePrint !== 'function') {
      throw new Error('文档尚未渲染完成，请稍后重试');
    }
    window.__iosPdfState = { x: window.scrollX, y: window.scrollY };
    window.preparePrint(keepBackground);
    const style = document.createElement('style');
    style.id = 'ios-pdf-style';
    style.textContent = `
      html.ios-pdf-export, html.ios-pdf-export body {
        width: ${width}px !important; height: auto !important; min-height: 0 !important;
        margin: 0 !important; padding: 0 !important; overflow: visible !important;
      }
      html.ios-pdf-export * { transition: none !important; animation: none !important; }
      html.ios-pdf-export .markdown-body {
        width: 100% !important; max-width: none !important; margin: 0 !important; padding: 0 !important;
      }
      html.ios-pdf-export.print-mode-white,
      html.ios-pdf-export.print-mode-white body,
      html.ios-pdf-export.print-mode-white .markdown-body { background: #fff !important; }
      html.ios-pdf-export pre, html.ios-pdf-export pre code {
        white-space: pre-wrap !important; word-break: break-all !important;
      }
      html.ios-pdf-export hr { visibility: hidden; border: 0 !important; margin: 0 !important; height: 0; }
    `;
    document.head.appendChild(style);
    document.documentElement.classList.add('ios-pdf-export');
    const images = Array.from(content.querySelectorAll('img'));
    await Promise.race([
      Promise.all([document.fonts.ready, ...images.map(img => img.complete ? Promise.resolve() :
        new Promise(resolve => {
          img.addEventListener('load', resolve, { once: true });
          img.addEventListener('error', resolve, { once: true });
        }))]),
      new Promise(resolve => setTimeout(resolve, 5000))
    ]);
    if (document.fonts.status === 'loading' || images.some(img => !img.complete)) {
      throw new Error('图片或字体尚未加载完成，请稍后重试');
    }
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const top = element => element.getBoundingClientRect().top + window.scrollY;
    const avoid = [];
    const addRect = rect => {
      if (rect.height > 0) avoid.push([rect.top + window.scrollY, rect.bottom + window.scrollY]);
    };
    // 文本行不能从字形中间切断；超长代码块、表格仍允许逐行分页。
    const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      if (!walker.currentNode.textContent.trim()) continue;
      const range = document.createRange();
      range.selectNodeContents(walker.currentNode);
      Array.from(range.getClientRects()).forEach(addRect);
    }
    content.querySelectorAll('p, li, blockquote, table, tr, pre, .callout, details, figure, img')
      .forEach(element => addRect(element.getBoundingClientRect()));
    content.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(heading => {
      const rect = heading.getBoundingClientRect();
      const next = heading.nextElementSibling;
      avoid.push([rect.top + window.scrollY, next ?
        Math.max(rect.bottom + window.scrollY, top(next) + 28) : rect.bottom + window.scrollY]);
    });
    return {
      height: Math.ceil(content.getBoundingClientRect().bottom + window.scrollY),
      breaks: Array.from(content.querySelectorAll('hr')).filter(hr => hr.nextElementSibling)
        .map(hr => top(hr.nextElementSibling)),
      avoid
    };
    """#

    private static let restoreScript = #"""
    (() => {
      const state = window.__iosPdfState;
      if (!state) return;
      document.getElementById('ios-pdf-style')?.remove();
      document.documentElement.classList.remove('ios-pdf-export');
      window.restoreAfterPrint();
      window.scrollTo(state.x, state.y);
      delete window.__iosPdfState;
    })();
    """#
}
