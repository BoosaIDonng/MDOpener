import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 首页：大圆按钮选择文件，右上角最近文档（仅本次运行有效）。
/// 视觉与交互对齐安卓 HomeScreen（呼吸动画 + 按压缩小）。
struct HomeScreen: View {
    @ObservedObject var model: AppModel
    let onSettings: () -> Void
    @State private var showPicker = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            BigOpenButton {
                showPicker = true
            }
            Text("点击选择 Markdown 文件")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.homeBg(colorScheme))
        .navigationTitle("MD Opener")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if model.lastFile != nil {
                    Button {
                        model.reopenLast()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("重开最近文档")
                }
                Button {
                    onSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
            }
        }
        .sheet(isPresented: $showPicker) {
            MarkdownDocumentPicker { url in
                showPicker = false
                model.openUrl(url)
            } onCancel: {
                showPicker = false
            }
        }
    }

    private var markdownContentTypes: [UTType] {
        [
            UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText),
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType(filenameExtension: "mdown") ?? .plainText,
            .plainText,
            .data
        ]
    }
}

/// UIKit's document picker accepts Files app provider URLs more reliably than SwiftUI's fileImporter.
/// The app only reads Markdown, so import a local copy instead of retaining a provider URL.
struct MarkdownDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController,
                                context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

    }
}

/// 大圆按钮：空闲呼吸脉冲、按下缩小（对齐安卓首页动效）
struct BigOpenButton: View {
    let action: () -> Void
    @State private var breathing = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "doc.text")
                .font(.system(size: 60, weight: .regular))
                .foregroundColor(.white)
                .frame(width: 180, height: 180)
                .background(
                    Circle().fill(Theme.lightAccent)
                )
        }
        .buttonStyle(PressScaleStyle())
        .scaleEffect(breathing ? 1.05 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
