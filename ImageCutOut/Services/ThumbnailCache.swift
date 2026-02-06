import Foundation
import AppKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cacheLimit = 100
    private var store: [URL: NSImage] = [:]
    private var order: [URL] = []
    private let lock = NSLock()

    func image(for url: URL, maxSize: CGSize = CGSize(width: 512, height: 512)) -> NSImage? {
        lock.lock()
        if let image = store[url] {
            lock.unlock()
            return image
        }
        lock.unlock()

        guard let source = NSImage(contentsOf: url) else { return nil }
        let resized = source.resized(toFit: maxSize)
        set(resized, for: url)
        return resized
    }

    func set(_ image: NSImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        store[url] = image
        order.removeAll { $0 == url }
        order.append(url)
        if order.count > cacheLimit, let oldest = order.first {
            store.removeValue(forKey: oldest)
            order.removeFirst()
        }
    }

    func clear() {
        lock.lock()
        store.removeAll()
        order.removeAll()
        lock.unlock()
    }
}

private extension NSImage {
    func resized(toFit size: CGSize) -> NSImage {
        let ratio = min(size.width / self.size.width, size.height / self.size.height)
        let newSize = CGSize(width: max(self.size.width * ratio, 1), height: max(self.size.height * ratio, 1))
        let image = NSImage(size: newSize)
        image.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .sourceOver, fraction: 1.0)
        image.unlockFocus()
        return image
    }
}
