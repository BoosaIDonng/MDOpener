import Foundation

/// 当前打开的文档。external = 由系统「打开方式」拉起，
/// 影响返回语义（应用内打开：工具栏返回退回主页；外部拉起：系统手势直接回来源 App）。
struct OpenedFile: Identifiable, Equatable {
    let id: UUID
    let url: URL?
    let name: String
    let content: String?
    let loading: Bool
    let error: Bool
    let external: Bool

    init(url: URL?, name: String, content: String? = nil,
         loading: Bool = false, error: Bool = false, external: Bool = false) {
        self.id = UUID()
        self.url = url
        self.name = name
        self.content = content
        self.loading = loading
        self.error = error
        self.external = external
    }
}

/// 目录条目（viewer.html 解析 h1–h3 后经 toc 消息回传）
struct TocItem: Identifiable, Equatable {
    let id: String
    let text: String
    let level: Int
}

/// PDF 导出纸张大小（rawValue 持久化到 UserDefaults，尺寸映射在 PdfExporter 做）
enum PdfPaperSize: String, CaseIterable, Identifiable {
    case a4 = "a4"
    case a5 = "a5"
    case b5 = "b5"
    case letter = "letter"
    case legal = "legal"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .a4: return "A4"
        case .a5: return "A5"
        case .b5: return "B5"
        case .letter: return "Letter"
        case .legal: return "Legal"
        }
    }

    static func from(_ id: String?) -> PdfPaperSize {
        PdfPaperSize(rawValue: id ?? "") ?? .a4
    }
}
