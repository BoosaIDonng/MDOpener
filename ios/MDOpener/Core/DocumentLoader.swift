import Foundation

/// 文档读取与编码检测，策略与安卓 UriReader 一致：
/// BOM 嗅探 → UTF-8 严格校验 → GB18030 回退（覆盖 GBK / GB2312），中文老文件不乱码。
enum DocumentLoader {

    static func load(_ url: URL, securityScopeAlreadyOpen: Bool = false) -> String? {
        // Keep the scope open when the caller acquired it before dispatching a background read.
        let scoped = securityScopeAlreadyOpen ? false : url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(4))
        // BOM 嗅探
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if bytes.count >= 2 {
            if bytes[0] == 0xFE, bytes[1] == 0xFF {
                return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
            }
            if bytes[0] == 0xFF, bytes[1] == 0xFE {
                return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
            }
        }
        // 无 BOM：先按 UTF-8 严格校验（String(data:encoding:) 遇非法序列返回 nil），
        // 失败则视为 GBK 系编码按 GB18030 解（超集，向下兼容 GBK / GB2312）
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        return String(data: data, encoding: gb18030)
    }
}
