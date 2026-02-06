import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Array where Element == NSItemProvider {
    func loadFileURLs(completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in self {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                }
            }
        }
        group.notify(queue: .main) {
            completion(urls)
        }
    }
}

extension NSImage {
    func cgImage() -> CGImage? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.cgImage
    }
}

extension View {
    func standardPanelStyle() -> some View {
        self
            .padding(12)
            .background(Color(nsColor: NSColor.windowBackgroundColor))
            .cornerRadius(8)
    }

}
