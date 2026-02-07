import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedProviderID: UUID?
    @State private var apiKeyInput: String = ""
    @State private var testResult: String?

    var body: some View {
        HStack(spacing: 0) {
            Form {
                cutoutSection
                batchSection
                exportSection
                csvSection
                uiSection
            }
            .formStyle(.grouped)
            .frame(minWidth: 420, idealWidth: 460)

            Divider()

            providerPane
                .frame(minWidth: 360, idealWidth: 420)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    resetDefaults()
                } label: {
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .onChange(of: selectedProviderID) { newValue in
            guard let id = newValue else {
                apiKeyInput = ""
                return
            }
            apiKeyInput = KeychainManager.shared.get("ai.key.\(id.uuidString)") ?? ""
        }
    }

    private var cutoutSection: some View {
        Section("Cutout Engine") {
            LabeledContent("Edge Quality") {
                Slider(value: $appState.settings.cutoutSettings.edgeQuality, in: 0...1)
            }
            LabeledContent("Feather") {
                Slider(value: $appState.settings.cutoutSettings.featherRadius, in: 0...12)
            }
            LabeledContent("Threshold") {
                Slider(value: $appState.settings.cutoutSettings.threshold, in: 0...1)
            }
            LabeledContent("Padding") {
                Slider(value: $appState.settings.cutoutSettings.paddingPercent, in: 0...30)
            }
            Toggle("Auto Crop", isOn: $appState.settings.cutoutSettings.autoCrop)
            Toggle("Hair/Fur Edge Mode", isOn: $appState.settings.cutoutSettings.hairEdgeMode)
            Toggle("Glass Handling", isOn: $appState.settings.cutoutSettings.glassHandlingMode)
        }
    }

    private var batchSection: some View {
        Section("Batch Processing") {
            Stepper("Concurrency: \(appState.settings.batchSettings.concurrencyLimit)", value: $appState.settings.batchSettings.concurrencyLimit, in: 1...6)
            Toggle("Recursive Folder Scan", isOn: $appState.settings.batchSettings.recursive)
            Toggle("Preserve EXIF", isOn: $appState.settings.batchSettings.preserveEXIF)
            Toggle("Retry on Failure", isOn: $appState.settings.batchSettings.retryOnFailure)
            Stepper("Max Retries: \(appState.settings.batchSettings.maxRetries)", value: $appState.settings.batchSettings.maxRetries, in: 0...5)
        }
    }

    private var exportSection: some View {
        Section("Export Rules") {
            TextField("Naming Rule", text: $appState.settings.exportSettings.namingRule)
            Toggle("Export JPG", isOn: $appState.settings.exportSettings.exportJPG)
            LabeledContent("JPG Quality") { Slider(value: $appState.settings.exportSettings.jpgQuality, in: 0.5...1.0) }
            LabeledContent("PNG Compression") { Slider(value: $appState.settings.exportSettings.pngCompression, in: 0...1.0) }
            Toggle("ZIP Package", isOn: $appState.settings.exportSettings.exportZipPackage)
            Toggle("Include Assets CSV", isOn: $appState.settings.exportSettings.includeAssetsCSV)
        }
    }

    private var providerPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Providers")
                    .font(.headline)
                Spacer()
                Button {
                    addProvider()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Provider")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            HStack(spacing: 0) {
                providerList
                Divider()
                providerEditor
            }

            if let testResult {
                Text(testResult)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    private var csvSection: some View {
        Section("CSV Mapping") {
            Button("Import CSV") { appState.importCSV() }
            Text("Entries: \(appState.settings.skuMapping.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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
        Section("UI") {
            Picker("Theme", selection: $appState.settings.uiSettings.theme) {
                ForEach(ThemeMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Button("Clear AI Cache") { AICache.shared.clear() }
        }
    }

    private var providerList: some View {
        List(selection: $selectedProviderID) {
            ForEach(appState.settings.providerProfiles) { profile in
                Label(profile.name, systemImage: "key")
                    .tag(profile.id as UUID?)
            }
            .onDelete { indexSet in
                appState.settings.providerProfiles.remove(atOffsets: indexSet)
            }
        }
        .frame(minWidth: 220)
    }

    private var providerEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let profileIndex = appState.settings.providerProfiles.firstIndex(where: { $0.id == selectedProviderID }) {
                let binding = $appState.settings.providerProfiles[profileIndex]
                Form {
                    Section("Profile") {
                        TextField("Name", text: binding.name)
                        Picker("Type", selection: binding.type) {
                            ForEach(AIProviderType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        TextField("Base URL", text: binding.baseURLString)
                        TextField("Model", text: binding.modelName)
                        Stepper("Timeout: \(Int(binding.timeoutSeconds.wrappedValue))s", value: binding.timeoutSeconds, in: 5...120)
                        Stepper("Rate Limit: \(binding.rateLimitPerMinute.wrappedValue)/min", value: binding.rateLimitPerMinute, in: 1...300)
                        Toggle("Enabled", isOn: binding.isEnabled)
                    }
                    Section("Authentication") {
                        SecureField("API Key", text: $apiKeyInput)
                        HStack {
                            Button("Save") { saveAPIKey(profile: binding.wrappedValue) }
                            Button("Test") { testConnection(profile: binding.wrappedValue) }
                            Spacer()
                            Button("Remove") { removeProvider() }
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                UnavailableView(title: "Select Provider", systemImage: "key", message: "Choose a provider from the list.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct UnavailableView: View {
        let title: String
        let systemImage: String
        let message: String

        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private func resetDefaults() {
        appState.settings.cutoutSettings = .default
        appState.settings.batchSettings = .default
        appState.settings.exportSettings = .default
        appState.settings.qualitySettings = .default
        appState.settings.uiSettings = .default
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
