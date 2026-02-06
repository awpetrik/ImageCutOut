import Foundation

final class AssetLibrary {
    static let shared = AssetLibrary()
    private let fileManager = FileManager.default
    private let libraryURL: URL
    private var index: [String: AssetMetadata] = [:]

    init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("ImageCutOut", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        libraryURL = dir.appendingPathComponent("asset-library.json")
        load()
    }

    func metadata(for url: URL) -> AssetMetadata? {
        index[url.path]
    }

    func update(metadata: AssetMetadata, for url: URL) {
        index[url.path] = metadata
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: libraryURL) else { return }
        if let decoded = try? JSONDecoder().decode([String: AssetMetadata].self, from: data) {
            index = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: libraryURL)
        }
    }
}
