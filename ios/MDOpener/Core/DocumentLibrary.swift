import Foundation

struct LibraryDocument: Identifiable, Equatable, Sendable {
    let url: URL
    let relativePath: String
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

/// 只保存目录索引；正文按需读取。对象存活期间持有整个文件夹的访问授权。
final class DocumentLibrary: Sendable {
    let rootURL: URL
    let documents: [LibraryDocument]
    private let accessing: Bool

    private init(rootURL: URL, documents: [LibraryDocument], accessing: Bool) {
        self.rootURL = rootURL
        self.documents = documents
        self.accessing = accessing
    }

    deinit {
        if accessing { rootURL.stopAccessingSecurityScopedResource() }
    }

    /// 接管选择器回调中已取得的作用域；读取失败时也负责释放。
    static func load(_ url: URL, securityScopeAlreadyOpen: Bool) throws -> DocumentLibrary {
        do {
            var result: Result<[LibraryDocument], Error>?
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { root in
                result = Result { try scan(root) }
            }
            if let coordinationError { throw coordinationError }
            guard let result else {
                throw CocoaError(.fileReadUnknown)
            }
            return DocumentLibrary(rootURL: url, documents: try result.get(),
                                   accessing: securityScopeAlreadyOpen)
        } catch {
            if securityScopeAlreadyOpen { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    private static func scan(_ url: URL) throws -> [LibraryDocument] {
        let root = url.resolvingSymlinksInPath().standardizedFileURL
        guard try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        var readError: Error?
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, error in readError = error; return false }) else {
            throw CocoaError(.fileReadNoPermission)
        }
        let boundary = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let extensions: Set<String> = ["md", "markdown", "mdown"]
        var documents: [LibraryDocument] = []
        for case let file as URL in enumerator {
            let values = try file.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            let canonical = file.resolvingSymlinksInPath().standardizedFileURL
            guard values.isRegularFile == true, extensions.contains(file.pathExtension.lowercased()),
                  canonical.path.hasPrefix(boundary) else { continue }
            documents.append(LibraryDocument(url: canonical,
                                              relativePath: String(canonical.path.dropFirst(boundary.count))))
        }
        if let readError { throw readError }
        return documents.sorted { lhs, rhs in
            let order = lhs.name.localizedStandardCompare(rhs.name)
            if order != .orderedSame { return order == .orderedAscending }
            let pathOrder = lhs.relativePath.localizedStandardCompare(rhs.relativePath)
            return pathOrder == .orderedSame
                ? lhs.relativePath < rhs.relativePath
                : pathOrder == .orderedAscending
        }
    }
}
