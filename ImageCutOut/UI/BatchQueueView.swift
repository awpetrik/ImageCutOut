import SwiftUI

struct BatchQueueView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var showNeedsReviewOnly: Bool = false
    @State private var showApprovedOnly: Bool = false
    @State private var sortOption: String = "processingTime"

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            List(selection: $appState.assetStore.selectedAssetIDs) {
                ForEach(filteredAssets) { asset in
                    GalleryItemRow(asset: asset)
                        .tag(asset.id)
                }
            }
            .listStyle(.inset)
            footer
        }
        .padding(12)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
            Toggle("Needs Review", isOn: $showNeedsReviewOnly)
            Toggle("Approved", isOn: $showApprovedOnly)
            Picker("Sort", selection: $sortOption) {
                Text("Processing Time").tag("processingTime")
                Text("File Size").tag("fileSize")
                Text("Confidence").tag("confidence")
            }
            Spacer()
            Button("Export Selected") { appState.exportSelected(includeOnlyApproved: false) }
            Button("Reprocess Selected") { reprocessSelected() }
            Button("Remove") { removeSelected() }
        }
    }

    private var footer: some View {
        HStack {
            Text("Total: \(appState.assetStore.allAssets().count)")
            Spacer()
            Text(String(format: "Speed: %.1f img/min", appState.batchProcessor.imagesPerMinute))
            Text(String(format: "Elapsed: %.0fs", appState.batchProcessor.elapsedSeconds))
            if appState.batchProcessor.imagesPerMinute > 0 {
                let remaining = max(0, appState.batchProcessor.totalCount - appState.batchProcessor.completedCount - appState.batchProcessor.failedCount)
                let minutes = Double(remaining) / appState.batchProcessor.imagesPerMinute
                Text(String(format: "ETA: %.1f min", minutes))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }

    private var filteredAssets: [AssetItem] {
        var items = appState.assetStore.allAssets()
        if !searchText.isEmpty {
            items = items.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }
        }
        if showNeedsReviewOnly {
            items = items.filter { $0.status == .needsReview }
        }
        if showApprovedOnly {
            items = items.filter { $0.approvalStatus == .approved }
        }
        switch sortOption {
        case "fileSize":
            items = items.sorted { ($0.processingInfo.fileSizeBytes ?? 0) > ($1.processingInfo.fileSizeBytes ?? 0) }
        case "confidence":
            items = items.sorted { ($0.processingInfo.confidenceScore ?? 0) > ($1.processingInfo.confidenceScore ?? 0) }
        default:
            items = items.sorted { ($0.processingInfo.durationSeconds ?? 0) > ($1.processingInfo.durationSeconds ?? 0) }
        }
        return items
    }

    private func reprocessSelected() {
        let selected = appState.assetStore.selectedAssetIDs
        guard !selected.isEmpty else { return }
        for id in selected {
            appState.assetStore.update(assetID: id) { item in
                item.status = .pending
                item.processingProgress = 0
            }
        }
        appState.startBatch()
    }

    private func removeSelected() {
        let selected = appState.assetStore.selectedAssetIDs
        guard !selected.isEmpty else { return }
        for id in selected {
            appState.assetStore.remove(assetID: id)
        }
        appState.assetStore.selectedAssetIDs.removeAll()
    }
}
