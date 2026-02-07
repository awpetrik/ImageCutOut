import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    dropZone
                    primaryActions
                    summaryPanel
                }
                .padding(20)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.openFiles()
                } label: {
                    Label("Open", systemImage: "folder.badge.plus")
                }
                Button {
                    appState.selectOutputFolder()
                } label: {
                    Label("Output Folder", systemImage: "folder")
                }
                Button {
                    appState.startBatch()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                Button {
                    appState.pauseBatch()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                Button {
                    appState.exportAssets(includeOnlyApproved: false)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ImageCutOut")
                .font(.title)
            Text("Batch-grade product cutouts with offline-first processing.")
                .foregroundStyle(.secondary)
        }
    }

    private var dropZone: some View {
        GroupBox {
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Drop images or folders")
                    .font(.headline)
                Text("Supports PNG, JPG, TIFF. You can also use Open to select files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                providers.loadFileURLs { urls in
                    appState.handleDrop(urls: urls)
                }
                return true
            }
        }
        .groupBoxStyle(.automatic)
        .background(isDropTargeted ? Color.secondary.opacity(0.08) : Color.clear)
    }

    private var primaryActions: some View {
        HStack(spacing: 12) {
            Button("Open") { appState.openFiles() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Choose Output") { appState.selectOutputFolder() }
            Button("Start Batch") { appState.startBatch() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var summaryPanel: some View {
        GroupBox("Batch Summary") {
            let total = appState.assetStore.allAssets().count
            let done = appState.assetStore.allAssets().filter { $0.status == .done }.count
            let failed = appState.assetStore.allAssets().filter { $0.status == .failed }.count
            let needsReview = appState.assetStore.allAssets().filter { $0.status == .needsReview }.count
            HStack(spacing: 24) {
                SummaryMetricView(label: "Total", value: total)
                SummaryMetricView(label: "Done", value: done)
                SummaryMetricView(label: "Needs Review", value: needsReview)
                SummaryMetricView(label: "Failed", value: failed)
            }
            .padding(.vertical, 4)
            if let message = appState.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SummaryMetricView: View {
    var label: String
    var value: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(value)").font(.title2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
