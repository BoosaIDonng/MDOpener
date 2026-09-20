import SwiftUI

/// 设置页：主题 / 字号 / 正文宽度，默认值与档位对齐安卓 SettingsScreen。
/// iOS 版无「检查更新」（侧载无意义，属计划不做清单），保留版本信息展示。
struct SettingsScreen: View {
    @ObservedObject var settings: SettingsStore
    let onBack: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Form {
            Section {
                Picker("主题", selection: $settings.themeMode) {
                    Text("跟随系统").tag(0)
                    Text("浅色").tag(1)
                    Text("深色").tag(2)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("主题")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("字号：\(settings.fontSize)pt")
                    Slider(
                        value: Binding(
                            get: { Double(settings.fontSize) },
                            set: { settings.fontSize = Int($0.rounded()) }),
                        in: 12...28,
                        step: 1)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("正文宽度：\(settings.maxWidth)pt")
                    Slider(
                        value: Binding(
                            get: { Double(settings.maxWidth) },
                            set: { settings.maxWidth = Int($0.rounded()) }),
                        in: 240...1100,
                        step: 20)
                    if settings.maxWidth > Int(screenWidth) {
                        Text("该档位超过本机屏宽（\(Int(screenWidth))pt），面向更宽设备")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("阅读")
            }

            Section {
                LabeledContent("当前版本", value: "v\(appVersion)")
                LabeledContent("分发方式", value: "侧载安装，更新见 GitHub Releases")
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("返回")
            }
        }
    }

    /// WebView 满屏铺开时 CSS 视口宽度≈屏幕 pt 宽（对齐安卓 screenWidthDp 语义）
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
