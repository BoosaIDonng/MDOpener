import SwiftUI

/// 导航根：主页 / 查看器 / 设置 三分支（对齐安卓 AppRoot）。
/// 返回语义：应用内文档与设置页逐级退回；外部拉起的文档由系统顶部
/// 「返回 xx」手势直接回来源 App，不经过应用内导航。
struct AppRoot: View {
    @ObservedObject var model: AppModel
    @StateObject private var settings = SettingsStore()
    @State private var showSettings = false
    @State private var showFolderPicker = false
    @State private var showDocuments = false
    @State private var openDocumentsAfterPicker = false
    @Environment(\.colorScheme) private var systemScheme

    private var isDark: Bool {
        switch settings.themeMode {
        case 2: return true
        case 1: return false
        default: return systemScheme == .dark
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let file = model.currentFile {
                    ViewerScreen(file: file, isDark: isDark, settings: settings,
                                 libraryRoot: model.libraryDocumentIndex == nil ? nil : model.library?.rootURL,
                                 nextDocument: model.nextLibraryDocument,
                                 onShowDocuments: model.library == nil ? nil : { showDocuments = true },
                                 onNextDocument: { document in model.openLibraryDocument(document) },
                                 onClose: model.closeCurrent)
                        // 外部连续打开文档时，搜索、目录、图片横幅和导出状态也需重置。
                        .id(file.id)
                } else if showSettings {
                    SettingsScreen(settings: settings, onBack: { showSettings = false })
                } else {
                    HomeScreen(model: model, onSettings: { showSettings = true },
                               onImportFolder: { showFolderPicker = true },
                               onShowDocuments: { showDocuments = true })
                }
            }
            // 外壳 tint 用暖纸/深炭主色，与正文排版同一视觉语言（对齐安卓 Theme）
            .tint(isDark ? Theme.darkAccent : Theme.lightAccent)
            // themeMode=0 跟随系统（nil 交还系统判定），否则强制对应外观
            .preferredColorScheme(settings.themeMode == 0 ? nil : (isDark ? .dark : .light))
        }
        .sheet(isPresented: $showFolderPicker, onDismiss: {
            if openDocumentsAfterPicker {
                openDocumentsAfterPicker = false
                showDocuments = true
            }
        }) {
            MarkdownDocumentPicker(contentTypes: [.folder], asCopy: false) { url in
                model.importFolder(url)
                openDocumentsAfterPicker = true
                showFolderPicker = false
            } onCancel: {
                showFolderPicker = false
            }
        }
        .sheet(isPresented: $showDocuments) {
            DocumentLibraryScreen(model: model) { document in
                model.openLibraryDocument(document)
                showDocuments = false
            }
        }
    }
}
