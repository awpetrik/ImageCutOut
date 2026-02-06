import Foundation

final class QueueStore {
    static let shared = QueueStore()
    private let fileManager = FileManager.default
    private let storeURL: URL

    init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("ImageCutOut", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        storeURL = dir.appendingPathComponent("queue.json")
    }

    func save(assets: [AssetItem]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(assets) {
            try? data.write(to: storeURL)
        }
    }

    func load() -> [AssetItem] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([AssetItem].self, from: data)) ?? []
    }

    func clear() {
        try? fileManager.removeItem(at: storeURL)
    }
}
