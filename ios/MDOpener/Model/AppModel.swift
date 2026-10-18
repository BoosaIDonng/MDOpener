import Foundation
import SwiftUI

/// 应用状态中枢，等价于安卓侧 MainViewModel：
/// 当前文档、最近文档；设置项在 ④ 接入后加入。
@MainActor
final class AppModel: ObservableObject {

    @Published var currentFile: OpenedFile?
    /// 最近成功读出内容的文档（仅内存，进程结束即失效），供主页一键重开
    @Published var lastFile: OpenedFile?
    @Published private(set) var library: DocumentLibrary?
    @Published private(set) var isLoadingLibrary = false
    @Published private(set) var libraryError: String?
    private var libraryRequest = UUID()
    private static let libraryBookmarkKey = "document_library_bookmark"

    init() {
        if let root = FolderGrantStore.load(key: Self.libraryBookmarkKey) {
            importFolder(root)
        }
    }

    func importFolder(_ url: URL) {
        let request = UUID()
        libraryRequest = request
        isLoadingLibrary = true
        libraryError = nil
        // 必须在系统选择器的回调返回前取得授权，之后交给索引对象管理。
        let scoped = url.startAccessingSecurityScopedResource()
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = Result { try DocumentLibrary.load(url, securityScopeAlreadyOpen: scoped) }
            await MainActor.run { [weak self] in
                guard let self, self.libraryRequest == request else { return }
                self.isLoadingLibrary = false
                switch result {
                case .success(let library):
                    self.library = library
                    FolderGrantStore.save(url, key: Self.libraryBookmarkKey)
                case .failure:
                    self.libraryError = "文件夹读取失败，请检查文件是否可用，或重新导入文件夹。"
                }
            }
        }
    }

    var libraryDocumentIndex: Int? {
        guard let url = currentFile?.url else { return nil }
        return library?.documents.firstIndex(where: { $0.url == url })
    }

    var nextLibraryDocument: LibraryDocument? {
        guard let library, let index = libraryDocumentIndex,
              index + 1 < library.documents.count else { return nil }
        return library.documents[index + 1]
    }

    func openLibraryDocument(_ document: LibraryDocument) {
        guard library?.documents.contains(where: { $0.id == document.id }) == true else { return }
        openUrl(document.url)
    }

    func openUrl(_ url: URL, external: Bool = false) {
        let name = url.lastPathComponent.isEmpty ? "document.md" : url.lastPathComponent
        // Acquire the Files app's security scope before the async task leaves the importer callback.
        let scoped = url.startAccessingSecurityScopedResource()
        let library = self.library
        let opening = OpenedFile(url: url, name: name, loading: true, external: external)
        currentFile = opening
        // 读取与编码检测在后台线程，避免大文档卡 UI
        Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let content = withExtendedLifetime(library) {
                DocumentLoader.load(url, securityScopeAlreadyOpen: scoped)
            }
            await MainActor.run { [weak self] in
                // 同一路径可以被关闭、重开；只接收本次打开请求的结果。
                guard let self, let cur = self.currentFile, cur.id == opening.id else { return }
                if let content {
                    self.currentFile = OpenedFile(
                        url: url, name: cur.name, content: content, external: cur.external)
                } else {
                    self.currentFile = OpenedFile(
                        url: url, name: cur.name, error: true, external: cur.external)
                }
            }
        }
    }

    func closeCurrent() {
        // 只记录成功读出内容的文档；读取失败的重开只会再次报错，没有记忆价值
        if let cur = currentFile, cur.content != nil {
            lastFile = cur
        }
        currentFile = nil
    }

    /// 从主页重开最近文档：视为应用内打开，返回手势退回主页而非退出 App
    func reopenLast() {
        guard let last = lastFile else { return }
        currentFile = OpenedFile(
            url: last.url, name: last.name, content: last.content, external: false)
    }
}
