import Foundation
import AppKit
@preconcurrency import Combine

@MainActor
final class AssetStore: ObservableObject {
    @Published private(set) var assets: [AssetItem] = []
    @Published var selectedAssetIDs: Set<UUID> = []

    var selectedAssetID: UUID? {
        selectedAssetIDs.first
    }

    func addAssets(urls: [URL]) {
        let newAssets = urls.map { url -> AssetItem in
            let key = FileAccessManager.shared.storeBookmark(for: url)
            return AssetItem(url: url, bookmarkKey: key)
        }
        assets.append(contentsOf: newAssets)
    }

    func setAssets(_ items: [AssetItem]) {
        assets = items
    }

    func remove(assetID: UUID) {
        assets.removeAll { $0.id == assetID }
    }

    func update(assetID: UUID, _ update: (inout AssetItem) -> Void) {
        guard let index = assets.firstIndex(where: { $0.id == assetID }) else { return }
        update(&assets[index])
    }

    func replaceAsset(assetID: UUID, with url: URL) {
        guard let index = assets.firstIndex(where: { $0.id == assetID }) else { return }
        let key = FileAccessManager.shared.storeBookmark(for: url)
        assets[index].url = url
        assets[index].fileName = url.deletingPathExtension().lastPathComponent
        assets[index].bookmarkKey = key
        assets[index].status = .pending
        assets[index].outputURL = nil
        assets[index].maskURL = nil
    }

    func asset(for id: UUID?) -> AssetItem? {
        guard let id else { return nil }
        return assets.first { $0.id == id }
    }

    func allAssets() -> [AssetItem] {
        assets
    }

    func pendingAssets() -> [AssetItem] {
        assets.filter { $0.status == .pending || $0.status == .needsReview }
    }

    func resetStatuses() {
        assets = assets.map { asset in
            var updated = asset
            if updated.status == .processing { updated.status = .pending }
            return updated
        }
    }
}
