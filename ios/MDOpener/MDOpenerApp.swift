import SwiftUI

@main
struct MDOpenerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            AppRoot(model: model)
                // 系统「打开方式」（文件 App 等外部拉起）：视为外部文档
                .onOpenURL { url in
                    model.openUrl(url, external: true)
                }
        }
    }
}
