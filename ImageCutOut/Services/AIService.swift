import Foundation

final class AIService {
    private let settings: SettingsStore
    private let log: LogStore

    init(settings: SettingsStore, log: LogStore) {
        self.settings = settings
        self.log = log
    }

    func activeProviders() -> [AIProvider] {
        settings.providerProfiles.filter { $0.isEnabled }.map { AIProviderRegistry.shared.provider(for: $0) }
    }

    func generateMetadata(for asset: AssetItem) async -> AIResult? {
        guard let provider = activeProviders().first else { return nil }
        var hints: [String: String] = [:]
        if provider.capabilities.supportsOCR, let ciImage = try? ImageProcessing.loadCIImage(from: asset.url) {
            let text = await OCRService.recognizeText(from: ciImage)
            if !text.isEmpty {
                hints["ocr"] = text.joined(separator: " ")
            }
        }
        let context = AIRequestContext(filename: asset.fileName, metadataHints: hints, locale: Locale.current.identifier)
        do {
            let result = try await provider.generateMetadata(filename: asset.fileName, context: context)
            return result
        } catch {
            log.log(.error, "AI metadata generation failed", context: error.localizedDescription)
            return nil
        }
    }
}
