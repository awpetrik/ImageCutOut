import SwiftUI
import QuickLookUI
import UniformTypeIdentifiers

struct PreviewView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showMaskEditor: Bool = false
    @State private var previewMode: PreviewMode = .cutout

    var body: some View {
        Group {
            if let asset = appState.assetStore.asset(for: appState.assetStore.selectedAssetID) {
                VStack(spacing: 0) {
                    QuickLookViewer(url: previewURL(for: asset))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .onDrop(of: [.fileURL], isTargeted: .constant(false)) { providers in
                            providers.loadFileURLs { urls in
                                guard let url = urls.first, let id = appState.assetStore.selectedAssetID else { return }
                                appState.assetStore.replaceAsset(assetID: id, with: url)
                            }
                            return true
                        }
                }
            } else {
                UnavailableView(title: "No Selection", systemImage: "photo.on.rectangle", message: "Select an item in the queue to preview.")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("Preview", selection: $previewMode) {
                    ForEach(PreviewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    setApproval(.approved)
                } label: {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                }
                Button {
                    setApproval(.flagged)
                } label: {
                    Label("Needs Review", systemImage: "exclamationmark.triangle.fill")
                }
                Button {
                    appState.exportSelected(includeOnlyApproved: false)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                Button {
                    showMaskEditor = true
                } label: {
                    Label("Edit Mask", systemImage: "wand.and.stars")
                }
            }
        }
        .sheet(isPresented: $showMaskEditor) {
            MaskEditorSheet(assetID: appState.assetStore.selectedAssetID)
        }
    }

    private func previewURL(for asset: AssetItem) -> URL {
        switch previewMode {
        case .original:
            return asset.url
        case .cutout:
            return asset.outputURL ?? asset.url
        case .mask:
            return asset.maskURL ?? asset.url
        }
    }

    private func setApproval(_ status: AssetApprovalStatus) {
        guard let id = appState.assetStore.selectedAssetID else { return }
        appState.assetStore.update(assetID: id) { item in
            item.approvalStatus = status
        }
    }
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

private enum PreviewMode: String, CaseIterable, Identifiable {
    case original
    case cutout
    case mask

    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .cutout: return "Cutout"
        case .mask: return "Mask"
        }
    }
}

struct QuickLookViewer: NSViewRepresentable {
    typealias NSViewType = QLPreviewView
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView(frame: .zero, style: .compact)!
        view.autostarts = true
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as QLPreviewItem
    }
}
