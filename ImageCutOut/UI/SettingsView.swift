import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedProviderID: UUID?
    @State private var apiKeyInput: String = ""
    @State private var testResult: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                cutoutSection
                batchSection
                exportSection
                aiSection
                csvSection
                uiSection
            }
            .padding(24)
        }
        .onChange(of: selectedProviderID) { _, newValue in
            guard let id = newValue else {
                apiKeyInput = ""
                return
            }
            apiKeyInput = KeychainManager.shared.get("ai.key.\(id.uuidString)") ?? ""
        }
    }

    private var cutoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cutout Engine").font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                SliderSetting(title: "Edge Quality", value: $appState.settings.cutoutSettings.edgeQuality, range: 0...1)
                SliderSetting(title: "Feather Radius", value: $appState.settings.cutoutSettings.featherRadius, range: 0...12)
                SliderSetting(title: "Threshold", value: $appState.settings.cutoutSettings.threshold, range: 0...1)
                SliderSetting(title: "Padding (%)", value: $appState.settings.cutoutSettings.paddingPercent, range: 0...30)
                Toggle("Auto Crop", isOn: $appState.settings.cutoutSettings.autoCrop)
                SliderSetting(title: "Min Object Size (%)", value: $appState.settings.cutoutSettings.minObjectSizePercent, range: 0...20)
                SliderSetting(title: "Confidence Threshold", value: $appState.settings.cutoutSettings.confidenceThreshold, range: 0...1)
            }
            VStack(alignment: .leading, spacing: 10) {
                Picker("Background", selection: $appState.settings.cutoutSettings.backgroundOption) {
                    ForEach(BackgroundOption.allCases) { option in
                        Text(option.rawValue.capitalized).tag(option)
                    }
                }
                Picker("Shadow", selection: $appState.settings.cutoutSettings.shadowMode) {
                    ForEach(ShadowMode.allCases) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                Toggle("Preserve Shadow Layer", isOn: $appState.settings.cutoutSettings.preserveShadowLayer)
                Toggle("Hair/Fur Edge Mode", isOn: $appState.settings.cutoutSettings.hairEdgeMode)
                Toggle("Glass Handling", isOn: $appState.settings.cutoutSettings.glassHandlingMode)
                Toggle("Despeckle", isOn: $appState.settings.cutoutSettings.despeckle)
                Toggle("Edge Smoothing", isOn: $appState.settings.cutoutSettings.edgeSmoothing)
                Toggle("Auto White Balance", isOn: $appState.settings.cutoutSettings.autoWhiteBalance)
                Toggle("Keep Largest Object Only", isOn: $appState.settings.cutoutSettings.keepLargestObjectOnly)
            }
        }
        .standardPanelStyle()
    }

    private var batchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Batch Processing").font(.headline)
            Stepper("Concurrency: \(appState.settings.batchSettings.concurrencyLimit)", value: $appState.settings.batchSettings.concurrencyLimit, in: 1...6)
            Toggle("Recursive Folder Scan", isOn: $appState.settings.batchSettings.recursive)
            Toggle("Preserve EXIF", isOn: $appState.settings.batchSettings.preserveEXIF)
            Toggle("Retry on Failure", isOn: $appState.settings.batchSettings.retryOnFailure)
            Stepper("Max Retries: \(appState.settings.batchSettings.maxRetries)", value: $appState.settings.batchSettings.maxRetries, in: 0...5)
        }
        .standardPanelStyle()
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export").font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                TextField("Naming Rule", text: $appState.settings.exportSettings.namingRule)
                    .textFieldStyle(.roundedBorder)
                Toggle("Export JPG", isOn: $appState.settings.exportSettings.exportJPG)
                SliderSetting(title: "JPG Quality", value: $appState.settings.exportSettings.jpgQuality, range: 0.5...1.0)
                SliderSetting(title: "PNG Compression", value: $appState.settings.exportSettings.pngCompression, range: 0.0...1.0)
                Toggle("Export ZIP Package", isOn: $appState.settings.exportSettings.exportZipPackage)
                Toggle("Include Assets CSV", isOn: $appState.settings.exportSettings.includeAssetsCSV)
                Toggle("Include PDF Report", isOn: $appState.settings.exportSettings.includePDFReport)
                Toggle("Include Originals", isOn: $appState.settings.exportSettings.includeOriginals)
            }
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Watermark", isOn: $appState.settings.exportSettings.includeWatermark)
                TextField("Watermark Text", text: $appState.settings.exportSettings.watermarkText)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .standardPanelStyle()
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Providers").font(.headline)
            HStack {
                providerList
                providerEditor
            }
            if let testResult {
                Text(testResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .standardPanelStyle()
    }

    private var csvSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKU Mapping").font(.headline)
            Button("Import CSV") { appState.importCSV() }
            Text("Entries: \(appState.settings.skuMapping.count)")
                .font(.caption)
        }
        .standardPanelStyle()
        .onDrop(of: [.fileURL], isTargeted: .constant(false)) { providers in
            providers.loadFileURLs { urls in
                guard let url = urls.first else { return }
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    let rows = try CSVParser.parse(text)
                    let mapping = rows.compactMap { row -> SKUMapEntry? in
                        guard let sku = row["sku"], let pattern = row["filename_pattern"] else { return nil }
                        return SKUMapEntry(sku: sku, filenamePattern: pattern, brand: row["brand"], category: row["category"], variant: row["variant"])
                    }
                    appState.settings.skuMapping = mapping
                } catch {
                    appState.logStore.log(.error, "CSV drop import failed", context: error.localizedDescription)
                }
            }
            return true
        }
    }

    private var uiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UI").font(.headline)
            Picker("Theme", selection: $appState.settings.uiSettings.theme) {
                ForEach(ThemeMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Button("Clear AI Cache") { AICache.shared.clear() }
        }
        .standardPanelStyle()
    }

    private var providerList: some View {
        VStack(alignment: .leading) {
            List(selection: $selectedProviderID) {
                ForEach(appState.settings.providerProfiles) { profile in
                    Text(profile.name).tag(profile.id as UUID?)
                }
                .onDelete { indexSet in
                    appState.settings.providerProfiles.remove(atOffsets: indexSet)
                }
            }
            HStack {
                Button("Add Provider") { addProvider() }
                Button("Remove") { removeProvider() }
            }
        }
        .frame(width: 220)
    }

    private var providerEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let profileIndex = appState.settings.providerProfiles.firstIndex(where: { $0.id == selectedProviderID }) {
                let binding = $appState.settings.providerProfiles[profileIndex]
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: binding.name)
                        .textFieldStyle(.roundedBorder)
                    Picker("Type", selection: binding.type) {
                        ForEach(AIProviderType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("Base URL", text: binding.baseURLString)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model", text: binding.modelName)
                        .textFieldStyle(.roundedBorder)
                    Stepper("Timeout: \(Int(binding.timeoutSeconds.wrappedValue))s", value: binding.timeoutSeconds, in: 5...120)
                    Stepper("Rate Limit: \(binding.rateLimitPerMinute.wrappedValue)/min", value: binding.rateLimitPerMinute, in: 1...300)
                    Toggle("Enabled", isOn: binding.isEnabled)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("API Key", text: $apiKeyInput)
                    HStack {
                        Button("Save API Key") { saveAPIKey(profile: binding.wrappedValue) }
                        Button("Test Connection") { testConnection(profile: binding.wrappedValue) }
                    }
                    let provider = AIProviderRegistry.shared.provider(for: binding.wrappedValue)
                    let caps = provider.capabilities
                    Text("Capabilities: Vision \(caps.supportsVision ? "yes" : "no"), OCR \(caps.supportsOCR ? "yes" : "no"), LLM \(caps.supportsLLM ? "yes" : "no"), Multimodal \(caps.supportsMultimodal ? "yes" : "no")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let estimate = provider.estimateUsage(for: appState.assetStore.allAssets().count)
                    Text(String(format: "Estimated cost: $%.2f for %d items", estimate.estimatedCostUSD, appState.assetStore.allAssets().count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a provider to edit")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addProvider() {
        let profile = AIProviderProfile(
            name: "New Provider",
            type: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            modelName: "gpt-4o-mini"
        )
        appState.settings.providerProfiles.append(profile)
        selectedProviderID = profile.id
    }

    private func removeProvider() {
        guard let id = selectedProviderID else { return }
        appState.settings.providerProfiles.removeAll { $0.id == id }
        selectedProviderID = nil
    }

    private func saveAPIKey(profile: AIProviderProfile) {
        do {
            try KeychainManager.shared.set(apiKeyInput, for: "ai.key.\(profile.id.uuidString)")
            testResult = "API key saved"
        } catch {
            testResult = "Failed to save API key"
        }
    }

    private func testConnection(profile: AIProviderProfile) {
        Task {
            let provider = AIProviderRegistry.shared.provider(for: profile)
            let ok = await provider.testConnection()
            await MainActor.run {
                testResult = ok ? "Connection successful" : "Connection failed"
            }
        }
    }
}

struct SliderSetting: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range)
            Text(String(format: "%.2f", value))
                .font(.caption)
                .frame(width: 50)
        }
    }
}

private extension Binding where Value == AIProviderProfile {
    var baseURLString: Binding<String> {
        Binding<String>(
            get: { wrappedValue.baseURL.absoluteString },
            set: { wrappedValue.baseURL = URL(string: $0) ?? wrappedValue.baseURL }
        )
    }
}
