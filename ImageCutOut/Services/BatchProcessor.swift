import Foundation
import AppKit
@preconcurrency import Combine

@MainActor
final class BatchProcessor: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var isCancelled = false
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var completedCount: Int = 0
    @Published private(set) var failedCount: Int = 0
    @Published private(set) var startTime: Date?
    @Published private(set) var elapsedSeconds: Double = 0
    @Published private(set) var imagesPerMinute: Double = 0

    private var engine: CutoutEngine
    private let assetStore: AssetStore
    private let settingsStore: SettingsStore
    private let log: LogStore
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var semaphore: AsyncSemaphore
    private var timer: Timer?

    init(assetStore: AssetStore, settingsStore: SettingsStore, log: LogStore) {
        self.assetStore = assetStore
        self.settingsStore = settingsStore
        self.log = log
        self.engine = CutoutEngine(logger: log)
        self.semaphore = AsyncSemaphore(value: settingsStore.batchSettings.concurrencyLimit)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        isCancelled = false
        startTime = Date()
        completedCount = 0
        failedCount = 0
        totalCount = assetStore.pendingAssets().count
        semaphore = AsyncSemaphore(value: settingsStore.batchSettings.concurrencyLimit)
        Task { await engine.updateModel(name: nil) }
        scheduleTimer()

        if totalCount == 0 {
            isRunning = false
            timer?.invalidate()
            return
        }

        for asset in assetStore.pendingAssets() {
            queueProcess(for: asset)
        }
    }

    func pause() {
        isPaused = true
        log.log(.info, "Batch paused")
    }

    func resume() {
        isPaused = false
        log.log(.info, "Batch resumed")
        for asset in assetStore.pendingAssets() {
            if tasks[asset.id] == nil {
                queueProcess(for: asset)
            }
        }
    }

    func cancel() {
        isCancelled = true
        isRunning = false
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        timer?.invalidate()
        log.log(.warning, "Batch cancelled")
    }

    private func queueProcess(for asset: AssetItem) {
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.semaphore.wait()
            defer { Task { await self.semaphore.signal() } }

            while await MainActor.run(body: { self.isPaused }) {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            if await MainActor.run(body: { self.isCancelled }) { return }

            await MainActor.run {
                self.assetStore.update(assetID: asset.id) { item in
                    item.status = .processing
                    item.processingProgress = 0.05
                    item.processingInfo.startedAt = Date()
                    item.errorMessage = nil
                }
            }

            let maxRetries = await MainActor.run { self.settingsStore.batchSettings.retryOnFailure ? self.settingsStore.batchSettings.maxRetries : 0 }
            var attempt = 0
            while attempt <= maxRetries {
                do {
                    let outputURL = try await self.process(asset: asset)
                    await MainActor.run {
                        self.assetStore.update(assetID: asset.id) { item in
                            item.status = item.processingInfo.warnings.isEmpty ? .done : .needsReview
                            item.processingProgress = 1.0
                            item.outputURL = outputURL
                            item.processingInfo.finishedAt = Date()
                            if let start = item.processingInfo.startedAt, let end = item.processingInfo.finishedAt {
                                item.processingInfo.durationSeconds = end.timeIntervalSince(start)
                            }
                        }
                        self.completedCount += 1
                    }
                    break
                } catch {
                    attempt += 1
                    if attempt > maxRetries {
                        await MainActor.run {
                            self.assetStore.update(assetID: asset.id) { item in
                                item.status = .failed
                                item.errorMessage = error.localizedDescription
                                item.processingProgress = 1.0
                                item.processingInfo.finishedAt = Date()
                            }
                            self.failedCount += 1
                        }
                    } else {
                        let backoff = pow(2.0, Double(attempt)) * 0.5
                        try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                    }
                }
            }

            await MainActor.run {
                self.tasks.removeValue(forKey: asset.id)
                if self.completedCount + self.failedCount >= self.totalCount {
                    self.isRunning = false
                    self.timer?.invalidate()
                }
            }
        }
        tasks[asset.id] = task
    }

    private func process(asset: AssetItem) async throws -> URL {
        let settings = settingsStore.cutoutSettings
        let preserveEXIF = settingsStore.batchSettings.preserveEXIF
        let sourceURL: URL
        if let key = asset.bookmarkKey, let resolved = FileAccessManager.shared.resolveBookmark(key) {
            sourceURL = resolved
        } else {
            sourceURL = asset.url
        }
        let accessStarted = SecurityScopedBookmarks.shared.startAccessing(sourceURL)
        defer { if accessStarted { SecurityScopedBookmarks.shared.stopAccessing(sourceURL) } }
        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent("ImageCutOut", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        let outputURL = tempFolder.appendingPathComponent("\(asset.id.uuidString).png")

        await MainActor.run {
            assetStore.update(assetID: asset.id) { item in
                item.processingProgress = 0.35
            }
        }
        let result = try await engine.process(url: sourceURL, settings: settings, preserveEXIF: preserveEXIF)
        await MainActor.run {
            assetStore.update(assetID: asset.id) { item in
                item.processingProgress = 0.7
            }
        }

        if preserveEXIF {
            let metadata = ImageIOUtils.readMetadata(from: sourceURL)
            try ImageIOUtils.writePNG(ciImage: result.outputImage, to: outputURL, metadata: metadata)
        } else {
            try ImageWriter.writePNG(ciImage: result.outputImage, to: outputURL, compression: settingsStore.exportSettings.pngCompression)
        }

        let maskURL = tempFolder.appendingPathComponent("\(asset.id.uuidString)-mask.png")
        try? ImageWriter.writePNG(ciImage: result.maskImage, to: maskURL, compression: 0)

        await MainActor.run {
            assetStore.update(assetID: asset.id) { item in
                item.processingInfo.warnings = result.warnings
                item.processingInfo.confidenceScore = result.confidenceScore
                item.maskURL = maskURL
                item.processingInfo.pixelWidth = Int(result.outputImage.extent.width)
                item.processingInfo.pixelHeight = Int(result.outputImage.extent.height)
                if !result.warnings.isEmpty {
                    item.status = .needsReview
                }
                let metrics = QualityAnalyzer.analyze(mask: result.maskImage, originalSize: result.outputImage.extent.size, settings: settingsStore.qualitySettings)
                item.quality = metrics
            }
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let size = attrs[.size] as? NSNumber {
            await MainActor.run {
                assetStore.update(assetID: asset.id) { item in
                    item.processingInfo.fileSizeBytes = size.int64Value
                }
            }
        }

        return outputURL
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let start = self.startTime else { return }
                self.elapsedSeconds = Date().timeIntervalSince(start)
                if self.elapsedSeconds > 0 {
                    self.imagesPerMinute = Double(self.completedCount) / (self.elapsedSeconds / 60.0)
                }
            }
        }
    }
}
