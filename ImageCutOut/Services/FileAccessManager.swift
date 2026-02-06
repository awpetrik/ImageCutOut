import Foundation

final class FileAccessManager {
    static let shared = FileAccessManager()
    private init() {}

    private let bookmarkPrefix = "ImageCutOut.Bookmark."

    func storeBookmark(for url: URL) -> String {
        let key = bookmarkPrefix + url.pathHash
        do {
            try SecurityScopedBookmarks.shared.saveBookmark(for: url, key: key)
        } catch {
            return key
        }
        return key
    }

    func resolveBookmark(_ key: String) -> URL? {
        SecurityScopedBookmarks.shared.resolveBookmark(for: key)
    }

    func withAccess<T>(to url: URL, _ block: () throws -> T) rethrows -> T {
        let accessed = SecurityScopedBookmarks.shared.startAccessing(url)
        defer {
            if accessed { SecurityScopedBookmarks.shared.stopAccessing(url) }
        }
        return try block()
    }
}

private extension URL {
    var pathHash: String {
        Data(path.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}
