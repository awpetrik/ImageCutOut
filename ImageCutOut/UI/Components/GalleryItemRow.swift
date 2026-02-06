import SwiftUI

struct GalleryItemRow: View {
    let asset: AssetItem

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(url: asset.url)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(asset.fileName)
                        .font(.headline)
                    Spacer()
                    StatusBadgeView(status: asset.status)
                }
                if asset.status == .processing {
                    ProgressBarView(value: asset.processingProgress)
                } else if let error = asset.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
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

struct ThumbnailView: View {
    let url: URL

    var body: some View {
        Group {
            if let image = ThumbnailCache.shared.image(for: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle().fill(Color.gray.opacity(0.2))
            }
        }
        .frame(width: 64, height: 64)
        .cornerRadius(6)
    }
}
