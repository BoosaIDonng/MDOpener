import Foundation
import SwiftUI

/// 应用状态中枢，等价于安卓侧 MainViewModel：
/// 当前文档、最近文档；设置项在 ④ 接入后加入。
@MainActor
final class AppModel: ObservableObject {

    @Published var currentFile: OpenedFile?
    /// 最近成功读出内容的文档（仅内存，进程结束即失效），供主页一键重开
    @Published var lastFile: OpenedFile?

    func openUrl(_ url: URL, external: Bool = false) {
        let name = url.lastPathComponent.isEmpty ? "document.md" : url.lastPathComponent
        // Acquire the Files app's security scope before the async task leaves the importer callback.
        let scoped = url.startAccessingSecurityScopedResource()
        currentFile = OpenedFile(url: url, name: name, loading: true, external: external)
        // 读取与编码检测在后台线程，避免大文档卡 UI
        Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let content = DocumentLoader.load(url, securityScopeAlreadyOpen: scoped)
            await MainActor.run { [weak self] in
                guard let self, let cur = self.currentFile, cur.url == url else { return }
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
