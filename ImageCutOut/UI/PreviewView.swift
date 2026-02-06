import SwiftUI
import CoreImage
import UniformTypeIdentifiers

struct PreviewView: View {
    @EnvironmentObject private var appState: AppState
    @State private var zoom: CGFloat = 1.0
    @State private var overlayOpacity: Double = 0.6
    @State private var showMaskEditor: Bool = false
    @State private var commentText: String = ""
    @State private var isDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            if let asset = appState.assetStore.asset(for: appState.assetStore.selectedAssetID) {
                headerControls(asset: asset)
                previewArea(asset: asset)
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                        providers.loadFileURLs { urls in
                            guard let url = urls.first, let id = appState.assetStore.selectedAssetID else { return }
                            appState.assetStore.replaceAsset(assetID: id, with: url)
                        }
                        return true
                    }
                metadataPanel(asset: asset)
            } else {
                Text("Select an asset from the queue to preview.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .sheet(isPresented: $showMaskEditor) {
            MaskEditorSheet(assetID: appState.assetStore.selectedAssetID)
        }
        .onChange(of: appState.assetStore.selectedAssetIDs) { _, _ in
            if let asset = appState.assetStore.asset(for: appState.assetStore.selectedAssetID) {
                commentText = asset.notes ?? ""
            } else {
                commentText = ""
            }
        }
    }

    private func headerControls(asset: AssetItem) -> some View {
        HStack {
            Picker("Comparison", selection: $appState.settings.uiSettings.comparisonMode) {
                ForEach(ComparisonMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Spacer()
            Text(String(format: "Zoom %.0f%%", zoom * 100))
                .font(.caption)
            Slider(value: $zoom, in: 0.5...2.5)
                .frame(width: 140)
            Button("Edit Mask") { showMaskEditor = true }
            Button("AI Metadata") { Task { await appState.applyAIToSelected() } }
            approvalButtons(asset: asset)
        }
    }

    private func approvalButtons(asset: AssetItem) -> some View {
        HStack {
            Button("Approve") { setApproval(.approved) }
            Button("Reject") { setApproval(.rejected) }
            Button("Flag") { setApproval(.flagged) }
        }
    }

    private func previewArea(asset: AssetItem) -> some View {
        HStack(spacing: 12) {
            if appState.settings.uiSettings.comparisonMode == .sideBySide {
                ImagePreviewPane(title: "Original", imageURL: asset.url, zoom: zoom)
                ImagePreviewPane(title: "Cutout", imageURL: asset.outputURL, zoom: zoom)
            } else if appState.settings.uiSettings.comparisonMode == .overlay {
                overlayView(asset: asset)
            } else if appState.settings.uiSettings.comparisonMode == .difference {
                differenceView(asset: asset)
            } else {
                ImagePreviewPane(title: "Cutout", imageURL: asset.outputURL, zoom: zoom)
            }
        }
        .frame(maxHeight: 420)
    }

    private func overlayView(asset: AssetItem) -> some View {
        ZStack {
            CheckerboardView()
            if let original = NSImage(contentsOf: asset.url) {
                Image(nsImage: original)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
            }
            if let outputURL = asset.outputURL, let output = NSImage(contentsOf: outputURL) {
                Image(nsImage: output)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .opacity(overlayOpacity)
            }
        }
        .overlay(alignment: .bottom) {
            HStack {
                Text("Overlay")
                Slider(value: $overlayOpacity, in: 0...1)
                    .frame(width: 160)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
        .cornerRadius(10)
    }

    private func differenceView(asset: AssetItem) -> some View {
        ZStack {
            CheckerboardView()
            if let diff = differenceImage(originalURL: asset.url, processedURL: asset.outputURL) {
                Image(nsImage: diff)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
            } else {
                Text("No processed image")
                    .foregroundStyle(.secondary)
            }
        }
        .cornerRadius(10)
    }

    private func metadataPanel(asset: AssetItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata & QC").font(.headline)
            HStack(spacing: 12) {
                Text("SKU: \(asset.metadata.sku ?? "-")")
                Text("Brand: \(asset.metadata.brand ?? "-")")
                Text("Category: \(asset.metadata.category ?? "-")")
            }
            if let edge = asset.quality.edgeSmoothnessScore {
                Text(String(format: "Edge smoothness: %.2f", edge))
            }
            if let artifacts = asset.quality.transparencyArtifactsScore {
                Text(String(format: "Transparency artifacts: %.2f", artifacts))
            }
            if !asset.processingInfo.warnings.isEmpty {
                Text("Warnings: \(asset.processingInfo.warnings.joined(separator: " | "))")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            TextField("Comment", text: $commentText)
                .textFieldStyle(.roundedBorder)
            Button("Save Comment") {
                appState.assetStore.update(assetID: asset.id) { item in
                    item.notes = commentText
                }
            }
        }
        .standardPanelStyle()
    }

    private func differenceImage(originalURL: URL, processedURL: URL?) -> NSImage? {
        guard let processedURL, let original = CIImage(contentsOf: originalURL), let processed = CIImage(contentsOf: processedURL) else { return nil }
        let diff = ImageProcessing.differenceImage(original: original, processed: processed)
        guard let cgImage = ImageProcessing.makeCGImage(from: diff) else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }

    private func setApproval(_ status: AssetApprovalStatus) {
        guard let id = appState.assetStore.selectedAssetID else { return }
        appState.assetStore.update(assetID: id) { item in
            item.approvalStatus = status
            item.notes = commentText
        }
    }
}
