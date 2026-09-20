import Foundation

/// 相对图片的文件夹授权持久化：security-scoped bookmark 存 UserDefaults。
/// iOS 沙盒按文件粒度授权（打开单个 .md 拿不到同目录其他文件），
/// 目录级访问必须由用户经文件夹选择器显式授予一次，此后跨会话有效。
enum FolderGrantStore {

    private static let key = "image_folder_bookmark"

    static func load() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: [],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return nil }
        if stale, let renewed = try? url.bookmarkData() {
            UserDefaults.standard.set(renewed, forKey: key)
        }
        return url
    }

    static func save(_ url: URL) {
        // 调用方须已 startAccessingSecurityScopedResource（iOS 上生成 bookmark 需在授权作用域内）
        if let data = try? url.bookmarkData() {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
