import SwiftUI

/// 导航根：主页 / 查看器状态切换（等价安卓 AppRoot 的三分支，设置页 ④ 接入）。
/// 返回语义与安卓对齐：应用内文档用工具栏返回退回主页；外部拉起的文档由系统
/// 顶部「返回 xx」手势直接回来源 App，不经过应用内导航。
struct AppRoot: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if let file = model.currentFile {
                    ViewerScreen(file: file, onClose: model.closeCurrent)
                } else {
                    HomeScreen(model: model)
                }
            }
        }
    }
}
