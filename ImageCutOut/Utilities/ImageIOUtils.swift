import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreImage

struct ImageIOUtils {
    static func readMetadata(from url: URL) -> [String: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [:] }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return [:] }
        return metadata
    }

    static func writePNG(ciImage: CIImage, to url: URL, metadata: [String: Any]?) throws {
        guard let cgImage = ImageProcessing.makeCGImage(from: ciImage) else { return }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        let meta = metadata as CFDictionary?
        CGImageDestinationAddImage(destination, cgImage, meta)
        CGImageDestinationFinalize(destination)
    }
}
