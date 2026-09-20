import Foundation
import SwiftUI

/// 设置持久化（UserDefaults），键名与默认值对齐安卓 Store.kt：
/// theme 0/1/2、font 17、maxw 720、pdf_paper a4、pdf_bg false、pdf_auto_open false。
@MainActor
final class SettingsStore: ObservableObject {

    @Published var themeMode: Int {
        didSet { UserDefaults.standard.set(themeMode, forKey: "theme") }
    }

    @Published var fontSize: Int {
        didSet { UserDefaults.standard.set(fontSize, forKey: "font") }
    }

    @Published var maxWidth: Int {
        didSet { UserDefaults.standard.set(maxWidth, forKey: "maxw") }
    }

    @Published var pdfPaper: String {
        didSet { UserDefaults.standard.set(pdfPaper, forKey: "pdf_paper") }
    }

    @Published var pdfKeepBackground: Bool {
        didSet { UserDefaults.standard.set(pdfKeepBackground, forKey: "pdf_bg") }
    }

    @Published var pdfAutoOpen: Bool {
        didSet { UserDefaults.standard.set(pdfAutoOpen, forKey: "pdf_auto_open") }
    }

    init() {
        let d = UserDefaults.standard
        themeMode = d.object(forKey: "theme") as? Int ?? 0
        fontSize = d.object(forKey: "font") as? Int ?? 17
        maxWidth = d.object(forKey: "maxw") as? Int ?? 720
        pdfPaper = d.string(forKey: "pdf_paper") ?? "a4"
        pdfKeepBackground = d.bool(forKey: "pdf_bg")
        pdfAutoOpen = d.bool(forKey: "pdf_auto_open")
    }
}
