import Foundation
import Combine

final class SettingsStore: ObservableObject {
    @Published var cutoutSettings: CutoutSettings {
        didSet { persist() }
    }
    @Published var batchSettings: BatchSettings {
        didSet { persist() }
    }
    @Published var exportSettings: ExportSettings {
        didSet { persist() }
    }
    @Published var qualitySettings: QualitySettings {
        didSet { persist() }
    }
    @Published var uiSettings: UISettings {
        didSet { persist() }
    }
    @Published var providerProfiles: [AIProviderProfile] {
        didSet { persist() }
    }
    @Published var skuMapping: [SKUMapEntry] {
        didSet { persist() }
    }

    private let storageKey = "ImageCutOut.Settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let payload = try? decoder.decode(SettingsPayload.self, from: data) {
            self.cutoutSettings = payload.cutoutSettings
            self.batchSettings = payload.batchSettings
            self.exportSettings = payload.exportSettings
            self.qualitySettings = payload.qualitySettings
            self.uiSettings = payload.uiSettings
            self.providerProfiles = payload.providerProfiles
            self.skuMapping = payload.skuMapping
        } else {
            self.cutoutSettings = .default
            self.batchSettings = .default
            self.exportSettings = .default
            self.qualitySettings = .default
            self.uiSettings = .default
            self.providerProfiles = []
            self.skuMapping = []
        }
    }

    private func persist() {
        let payload = SettingsPayload(
            cutoutSettings: cutoutSettings,
            batchSettings: batchSettings,
            exportSettings: exportSettings,
            qualitySettings: qualitySettings,
            uiSettings: uiSettings,
            providerProfiles: providerProfiles,
            skuMapping: skuMapping
        )
        guard let data = try? encoder.encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

private struct SettingsPayload: Codable {
    var cutoutSettings: CutoutSettings
    var batchSettings: BatchSettings
    var exportSettings: ExportSettings
    var qualitySettings: QualitySettings
    var uiSettings: UISettings
    var providerProfiles: [AIProviderProfile]
    var skuMapping: [SKUMapEntry]
}
