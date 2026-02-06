import Foundation
import AppKit

extension NSImage {
    func addingWatermark(text: String) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(12, size.width * 0.04)),
            .foregroundColor: NSColor.white.withAlphaComponent(0.6)
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let textSize = attributed.size()
        let margin: CGFloat = 16
        let rect = NSRect(x: size.width - textSize.width - margin, y: margin, width: textSize.width, height: textSize.height)
        attributed.draw(in: rect)
        image.unlockFocus()
        return image
    }
}
