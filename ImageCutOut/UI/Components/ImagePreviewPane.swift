import SwiftUI

struct ImagePreviewPane: View {
    var title: String
    var imageURL: URL?
    var zoom: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ZStack {
                CheckerboardView()
                if let url = imageURL, let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoom)
                } else {
                    Text("No image")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(8)
        }
        .padding(8)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}
