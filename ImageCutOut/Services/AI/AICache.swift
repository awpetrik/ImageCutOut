import Foundation

final class AICache {
    static let shared = AICache()

    private let fileManager = FileManager.default
    private let cacheURL: URL
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 60 * 60 * 24 * 7) {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheURL = base.appendingPathComponent("ImageCutOut/AICache", isDirectory: true)
        self.ttl = ttl
        if !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
    }

    func load(key: String) -> AIResult? {
        let url = cacheURL.appendingPathComponent(key + ".json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedAIResult.self, from: data) else { return nil }
        if Date().timeIntervalSince(cached.timestamp) > ttl {
            try? fileManager.removeItem(at: url)
            return nil
        }
        return cached.result
    }

    func save(key: String, result: AIResult) {
        let cached = CachedAIResult(timestamp: Date(), result: result)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        let url = cacheURL.appendingPathComponent(key + ".json")
        try? data.write(to: url)
    }

    func clear() {
        try? fileManager.removeItem(at: cacheURL)
        try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    }
}

private struct CachedAIResult: Codable {
    var timestamp: Date
    var result: AIResult
}
