import SwiftUI

struct InspectorPanelView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if let asset = appState.assetStore.asset(for: appState.assetStore.selectedAssetID) {
                itemInspector(asset: asset)
            } else {
                batchInspector
            }
        }
        .frame(minWidth: 280, idealWidth: 320)
        .padding(16)
    }

    private var batchInspector: some View {
        Form {
            Section("Batch Settings") {
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
            }

            Section("Output") {
                Toggle("Export JPG", isOn: $appState.settings.exportSettings.exportJPG)
                Toggle("Include Assets CSV", isOn: $appState.settings.exportSettings.includeAssetsCSV)
                Toggle("ZIP Package", isOn: $appState.settings.exportSettings.exportZipPackage)
            }
        }
        .formStyle(.grouped)
    }

    private func itemInspector(asset: AssetItem) -> some View {
        Form {
            Section("Selected Item") {
                LabeledContent("Filename") { Text(asset.fileName).foregroundStyle(.secondary) }
                LabeledContent("Status") { Text(asset.status.rawValue.capitalized) }
                if let confidence = asset.processingInfo.confidenceScore {
                    LabeledContent("Confidence") { Text(String(format: "%.2f", confidence)) }
                }
            }

            Section("Metadata") {
                TextField("SKU", text: Binding(get: { asset.metadata.sku ?? "" }, set: { newValue in
                    appState.assetStore.update(assetID: asset.id) { item in item.metadata.sku = newValue }
                }))
                TextField("Brand", text: Binding(get: { asset.metadata.brand ?? "" }, set: { newValue in
                    appState.assetStore.update(assetID: asset.id) { item in item.metadata.brand = newValue }
                }))
                TextField("Category", text: Binding(get: { asset.metadata.category ?? "" }, set: { newValue in
                    appState.assetStore.update(assetID: asset.id) { item in item.metadata.category = newValue }
                }))
            }

            Section("Actions") {
                Button("AI Metadata") { Task { await appState.applyAIToSelected() } }
                Button("Export Selected") { appState.exportSelected(includeOnlyApproved: false) }
            }
        }
        .formStyle(.grouped)
    }
}
