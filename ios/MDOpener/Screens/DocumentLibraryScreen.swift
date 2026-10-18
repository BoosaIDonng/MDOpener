import SwiftUI

struct DocumentLibraryScreen: View {
    @ObservedObject var model: AppModel
    let onSelect: (LibraryDocument) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var documents: [LibraryDocument] {
        let all = model.library?.documents ?? []
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return search.isEmpty ? all : all.filter { $0.relativePath.localizedStandardContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                if model.isLoadingLibrary {
                    ProgressView("正在读取文件夹…")
                }
                if let error = model.libraryError {
                    Text(error).foregroundColor(.secondary)
                }
                if let library = model.library {
                    Section {
                        if documents.isEmpty && !model.isLoadingLibrary {
                            Text(query.isEmpty ? "此文件夹及子文件夹中没有 Markdown 文档" : "没有匹配的文档")
                                .foregroundColor(.secondary)
                        }
                        ForEach(documents) { document in
                            Button {
                                onSelect(document)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(document.name).foregroundColor(.primary)
                                        Text(document.relativePath)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if model.currentFile?.url == document.url {
                                        Image(systemName: "checkmark")
                                            .accessibilityLabel("正在阅读")
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                        }
                    } header: {
                        Text("\(library.documents.count) 篇 · 按文件名自然排序（含子文件夹）")
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索文件名或路径")
            .navigationTitle(model.library?.rootURL.lastPathComponent ?? "文件夹文档")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let root = model.library?.rootURL { model.importFolder(root) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("刷新文件夹")
                    .disabled(model.isLoadingLibrary || model.library == nil)
                }
            }
        }
    }
}
