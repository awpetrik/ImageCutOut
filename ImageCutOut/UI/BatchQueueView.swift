import SwiftUI
import AppKit

struct BatchQueueView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var filter: QueueFilter = .all
    @State private var sortOption: QueueSort = .processingTime

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $appState.assetStore.selectedAssetIDs) {
                ForEach(filteredAssets) { asset in
                    QueueRowView(asset: asset)
                        .contextMenu {
                            Button("Approve") { setApproval(asset, status: .approved) }
                            Button("Needs Review") { setApproval(asset, status: .flagged) }
                            Divider()
                            Button("Export") { appState.exportSelected(includeOnlyApproved: false) }
                            Button("Reprocess") { reprocess(asset) }
                            Button("Reveal in Finder") { reveal(asset) }
                        }
                        .tag(asset.id)
                }
            }
            .listStyle(.inset)
            .searchable(text: $searchText)
            statusBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("Filter", selection: $filter) {
                    ForEach(QueueFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("Sort", selection: $sortOption) {
                    ForEach(QueueSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.menu)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.exportSelected(includeOnlyApproved: false)
                } label: {
                    Label("Export Selected", systemImage: "square.and.arrow.up")
                }
                Button {
                    reprocessSelected()
                } label: {
                    Label("Reprocess", systemImage: "arrow.clockwise")
                }
                Button {
                    removeSelected()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            Text("Total \(appState.assetStore.allAssets().count)")
            Text(String(format: "Speed %.1f img/min", appState.batchProcessor.imagesPerMinute))
            Text(String(format: "Elapsed %.0fs", appState.batchProcessor.elapsedSeconds))
            if appState.batchProcessor.imagesPerMinute > 0 {
                let remaining = max(0, appState.batchProcessor.totalCount - appState.batchProcessor.completedCount - appState.batchProcessor.failedCount)
                let minutes = Double(remaining) / appState.batchProcessor.imagesPerMinute
                Text(String(format: "ETA %.1f min", minutes))
            }
            Spacer()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var filteredAssets: [AssetItem] {
        var items = appState.assetStore.allAssets()
        if !searchText.isEmpty {
            items = items.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }
        }
        items = filter.apply(to: items)
        return sortOption.sort(items)
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

    private func setApproval(_ asset: AssetItem, status: AssetApprovalStatus) {
        appState.assetStore.update(assetID: asset.id) { item in
            item.approvalStatus = status
        }
    }

    private func reprocess(_ asset: AssetItem) {
        appState.assetStore.update(assetID: asset.id) { item in
            item.status = .pending
            item.processingProgress = 0
        }
        appState.startBatch()
    }

    private func reveal(_ asset: AssetItem) {
        NSWorkspace.shared.activateFileViewerSelecting([asset.url])
    }
}

private enum QueueFilter: String, CaseIterable, Identifiable {
    case all
    case needsReview
    case approved
    case failed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .needsReview: return "Needs Review"
        case .approved: return "Approved"
        case .failed: return "Failed"
        }
    }

    func apply(to items: [AssetItem]) -> [AssetItem] {
        switch self {
        case .all: return items
        case .needsReview: return items.filter { $0.status == .needsReview }
        case .approved: return items.filter { $0.approvalStatus == .approved }
        case .failed: return items.filter { $0.status == .failed }
        }
    }
}

private enum QueueSort: String, CaseIterable, Identifiable {
    case processingTime
    case fileSize
    case confidence

    var id: String { rawValue }
    var title: String {
        switch self {
        case .processingTime: return "Processing Time"
        case .fileSize: return "File Size"
        case .confidence: return "Confidence"
        }
    }

    func sort(_ items: [AssetItem]) -> [AssetItem] {
        switch self {
        case .fileSize:
            return items.sorted { ($0.processingInfo.fileSizeBytes ?? 0) > ($1.processingInfo.fileSizeBytes ?? 0) }
        case .confidence:
            return items.sorted { ($0.processingInfo.confidenceScore ?? 0) > ($1.processingInfo.confidenceScore ?? 0) }
        case .processingTime:
            return items.sorted { ($0.processingInfo.durationSeconds ?? 0) > ($1.processingInfo.durationSeconds ?? 0) }
        }
    }
}

private struct QueueRowView: View {
    let asset: AssetItem

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(url: asset.url)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(asset.fileName)
                        .lineLimit(1)
                    Spacer()
                    StatusBadgeView(status: asset.status)
                }
                if asset.status == .processing {
                    ProgressView(value: asset.processingProgress)
                        .progressViewStyle(.linear)
                }
                HStack(spacing: 12) {
                    if let duration = asset.processingInfo.durationSeconds {
                        Text(String(format: "%.1fs", duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let confidence = asset.processingInfo.confidenceScore {
                        Text(String(format: "Conf %.2f", confidence))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
