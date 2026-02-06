import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                actionPanel
                summaryPanel
                tipsPanel
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ImageCutOut")
                .font(.largeTitle)
            Text("Batch-grade product cutouts with offline-first processing.")
                .foregroundStyle(.secondary)
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions").font(.headline)
            HStack {
                Button("Open Files") { appState.openFiles() }
                Button("Open Folder") { appState.openFolder() }
                Button("Select Output Folder") { appState.selectOutputFolder() }
            }
            HStack {
                Button("Start Batch") { appState.startBatch() }
                Button("Pause") { appState.pauseBatch() }
                Button("Resume") { appState.resumeBatch() }
                Button("Export All") { appState.exportAssets(includeOnlyApproved: false) }
                Button("Export Approved") { appState.exportAssets(includeOnlyApproved: true) }
            }
        }
        .standardPanelStyle()
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Batch Summary").font(.headline)
            let total = appState.assetStore.allAssets().count
            let done = appState.assetStore.allAssets().filter { $0.status == .done }.count
            let failed = appState.assetStore.allAssets().filter { $0.status == .failed }.count
            let needsReview = appState.assetStore.allAssets().filter { $0.status == .needsReview }.count
            HStack {
                SummaryMetricView(label: "Total", value: total)
                SummaryMetricView(label: "Done", value: done)
                SummaryMetricView(label: "Needs Review", value: needsReview)
                SummaryMetricView(label: "Failed", value: failed)
            }
            if let message = appState.statusMessage {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }
        .standardPanelStyle()
    }

    private var tipsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tips").font(.headline)
            Text("Use CSV import in Settings to map SKUs and enforce naming rules.")
            Text("Enable Auto-crop + Padding for planogram-ready assets.")
            Text("Use Needs Review filter in Batch Queue to focus QA.")
        }
        .standardPanelStyle()
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
