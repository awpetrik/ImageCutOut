import Foundation
import AppKit
import UniformTypeIdentifiers
@preconcurrency import Combine

@MainActor
final class AppState: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    var settings: SettingsStore
    var assetStore: AssetStore
    var logStore: LogStore
    var batchProcessor: BatchProcessor
    let aiService: AIService

    @Published var showResumePrompt: Bool = false
    @Published var lastExportURL: URL?
    @Published var statusMessage: String?
    @Published var currentSection: AppSection = .home

    private var autosaveTimer: Timer?

    init() {
        self.settings = SettingsStore()
        self.assetStore = AssetStore()
        self.logStore = LogStore()
        self.batchProcessor = BatchProcessor(assetStore: assetStore, settingsStore: settings, log: logStore)
        self.aiService = AIService(settings: settings, log: logStore)
        loadQueue()
        scheduleAutosave()
    }

    func handleDrop(urls: [URL]) {
        assetStore.addAssets(urls: urls)
        applySKUMap()
    }

    func openFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            assetStore.addAssets(urls: panel.urls)
            applySKUMap()
        }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let folder = panel.url {
            let started = SecurityScopedBookmarks.shared.startAccessing(folder)
            defer { if started { SecurityScopedBookmarks.shared.stopAccessing(folder) } }
            let urls = collectImages(in: folder, recursive: settings.batchSettings.recursive)
            assetStore.addAssets(urls: urls)
            applySKUMap()
        }
    }

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let folder = panel.url {
            let key = "ImageCutOut.OutputFolder"
            try? SecurityScopedBookmarks.shared.saveBookmark(for: folder, key: key)
            settings.exportSettings.outputFolderBookmarkKey = key
        }
    }

    func startBatch() {
        assetStore.resetStatuses()
        batchProcessor.start()
    }

    func pauseBatch() {
        batchProcessor.pause()
    }

    func resumeBatch() {
        batchProcessor.resume()
    }

    func cancelBatch() {
        batchProcessor.cancel()
    }

    func applyAIToSelected() async {
        guard let asset = assetStore.asset(for: assetStore.selectedAssetID) else { return }
        if let result = await aiService.generateMetadata(for: asset) {
            assetStore.update(assetID: asset.id) { item in
                item.metadata = result.metadata
                item.metadata.generatedAt = result.createdAt
                item.metadata.tags = result.tags
            }
            AssetLibrary.shared.update(metadata: result.metadata, for: asset.url)
        }
    }

    func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let rows = try CSVParser.parse(text)
                let mapping = rows.compactMap { row -> SKUMapEntry? in
                    guard let sku = row["sku"], let pattern = row["filename_pattern"] else { return nil }
                    return SKUMapEntry(sku: sku, filenamePattern: pattern, brand: row["brand"], category: row["category"], variant: row["variant"])
                }
                settings.skuMapping = mapping
                applySKUMap()
            } catch {
                logStore.log(.error, "CSV import failed", context: error.localizedDescription)
            }
        }
    }

    func exportAssets(includeOnlyApproved: Bool) {
        exportAssets(assets: assetStore.allAssets(), includeOnlyApproved: includeOnlyApproved)
    }

    func exportSelected(includeOnlyApproved: Bool) {
        let selected = assetStore.selectedAssetIDs
        guard !selected.isEmpty else {
            exportAssets(includeOnlyApproved: includeOnlyApproved)
            return
        }
        let assets = assetStore.allAssets().filter { selected.contains($0.id) }
        exportAssets(assets: assets, includeOnlyApproved: includeOnlyApproved)
    }

    private func exportAssets(assets: [AssetItem], includeOnlyApproved: Bool) {
        guard let key = settings.exportSettings.outputFolderBookmarkKey,
              let folder = SecurityScopedBookmarks.shared.resolveBookmark(for: key) else {
            selectOutputFolder()
            return
        }
        let started = SecurityScopedBookmarks.shared.startAccessing(folder)
        defer { if started { SecurityScopedBookmarks.shared.stopAccessing(folder) } }
        do {
            let exportURL = try Exporter.export(
                assets: assets,
                settings: settings.exportSettings,
                includeOnlyApproved: includeOnlyApproved,
                outputFolder: folder,
                skuMapping: settings.skuMapping,
                log: logStore
            )
            lastExportURL = exportURL
            statusMessage = "Exported to \(exportURL.lastPathComponent)"
        } catch {
            logStore.log(.error, "Export failed", context: error.localizedDescription)
        }
    }

    func clearQueue() {
        assetStore.setAssets([])
        QueueStore.shared.clear()
    }

    private func loadQueue() {
        let saved = QueueStore.shared.load()
        if !saved.isEmpty {
            assetStore.setAssets(saved)
            if saved.contains(where: { $0.status == .processing }) {
                showResumePrompt = true
            }
            applySKUMap()
        }
    }

    private func scheduleAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                QueueStore.shared.save(assets: self.assetStore.allAssets())
            }
        }
    }

    private func collectImages(in folder: URL, recursive: Bool) -> [URL] {
        let manager = FileManager.default
        var urls: [URL] = []
        let options: FileManager.DirectoryEnumerationOptions = recursive ? [] : [.skipsSubdirectoryDescendants]
        if let enumerator = manager.enumerator(at: folder, includingPropertiesForKeys: nil, options: options) {
            for case let url as URL in enumerator {
                if ["png", "jpg", "jpeg", "tiff"].contains(url.pathExtension.lowercased()) {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    private func applySKUMap() {
        let mapping = settings.skuMapping
        guard !mapping.isEmpty else { return }
        for asset in assetStore.allAssets() {
            if let entry = SKUMapper.match(for: asset.fileName, mapping: mapping) {
                assetStore.update(assetID: asset.id) { item in
                    item.metadata.sku = entry.sku
                    item.metadata.brand = entry.brand ?? item.metadata.brand
                    item.metadata.category = entry.category ?? item.metadata.category
                    item.metadata.variant = entry.variant ?? item.metadata.variant
                }
            }
        }
    }
}
