import Foundation
import CoreImage

struct ImageProcessing {
    private struct SendableContext: @unchecked Sendable {
        let value: CIContext
    }

    private static let context = SendableContext(value: CIContext(options: [.useSoftwareRenderer: false]))

    static func loadCIImage(from url: URL) throws -> CIImage {
        guard let image = CIImage(contentsOf: url) else {
            throw ImageProcessingError.cannotLoadImage
        }
        return image.orientedForExif()
    }

    static func makeCGImage(from image: CIImage) -> CGImage? {
        let extent = image.extent
        return context.value.createCGImage(image, from: extent)
    }

    static func applyMask(image: CIImage, mask: CIImage) -> CIImage {
        let masked = image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey: mask,
            kCIInputBackgroundImageKey: CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: image.extent)
        ])
        return masked
    }

    static func feather(mask: CIImage, radius: Double) -> CIImage {
        guard radius > 0 else { return mask }
        return mask.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
    }

    static func threshold(mask: CIImage, value: Double) -> CIImage {
        let clamped = mask.applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: CGFloat(value), y: CGFloat(value), z: CGFloat(value), w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])
        return clamped
    }

    static func autoCrop(image: CIImage, mask: CIImage, paddingPercent: Double) -> CIImage {
        let bounding = mask.boundingBoxOfVisiblePixels(threshold: 0.1)
        guard !bounding.isNull else { return image }
        let padded = bounding.insetBy(dx: -bounding.width * CGFloat(paddingPercent / 100), dy: -bounding.height * CGFloat(paddingPercent / 100))
        let clipped = image.cropped(to: padded.intersection(image.extent))
        return clipped
    }

    static func addPadding(image: CIImage, percent: Double) -> CIImage {
        guard percent > 0 else { return image }
        let extent = image.extent
        let padX = extent.width * CGFloat(percent / 100)
        let padY = extent.height * CGFloat(percent / 100)
        let newRect = extent.insetBy(dx: -padX, dy: -padY)
        let background = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: newRect)
        return image.composited(over: background)
    }

    static func addWhiteBackground(image: CIImage) -> CIImage {
        let background = CIImage(color: .white).cropped(to: image.extent)
        return image.composited(over: background)
    }

    static func addShadow(image: CIImage, radius: Double = 8, opacity: Double = 0.35) -> CIImage {
        let shadow = image
            .applyingFilter("CIMaskToAlpha")
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
            ])
        return image.composited(over: shadow)
    }

    static func despeckle(mask: CIImage, radius: Double = 1) -> CIImage {
        let minFilter = mask.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: radius])
        let maxFilter = minFilter.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius])
        return maxFilter
    }

    static func smoothEdges(mask: CIImage, radius: Double = 1.5) -> CIImage {
        mask.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
    }

    static func autoAdjust(image: CIImage) -> CIImage {
        let filters = image.autoAdjustmentFilters(options: [CIImageAutoAdjustmentOption.redEye: false])
        return filters.reduce(image) { result, filter in
            filter.setValue(result, forKey: kCIInputImageKey)
            return filter.outputImage ?? result
        }
    }

    static func differenceImage(original: CIImage, processed: CIImage) -> CIImage {
        original.applyingFilter("CIDifferenceBlendMode", parameters: [kCIInputBackgroundImageKey: processed])
    }

    static func resize(image: CIImage, targetSize: CGSize, maintainAspect: Bool) -> CIImage {
        let extent = image.extent
        let scaleX = targetSize.width / extent.width
        let scaleY = targetSize.height / extent.height
        if maintainAspect {
            let scale = min(scaleX, scaleY)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let scaled = image.transformed(by: transform)
            let background = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: CGRect(origin: .zero, size: targetSize))
            let x = (targetSize.width - scaled.extent.width) / 2
            let y = (targetSize.height - scaled.extent.height) / 2
            return scaled.transformed(by: CGAffineTransform(translationX: x, y: y)).composited(over: background)
        } else {
            let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            return image.transformed(by: transform)
        }
    }
}

enum ImageProcessingError: Error {
    case cannotLoadImage
}

extension CIImage {
    func orientedForExif() -> CIImage {
        guard let orientation = properties[kCGImagePropertyOrientation as String] as? UInt32 else { return self }
        return oriented(forExifOrientation: Int32(orientation))
    }

    func boundingBoxOfVisiblePixels(threshold: CGFloat) -> CGRect {
        guard let cgImage = ImageProcessing.makeCGImage(from: self) else { return .null }
        guard let data = cgImage.dataProvider?.data else { return .null }
        let bytes = CFDataGetBytePtr(data)
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let components = cgImage.bitsPerPixel / 8

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * components
                let alpha = CGFloat(bytes?[offset + components - 1] ?? 0) / 255.0
                if alpha > threshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        if minX > maxX || minY > maxY { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
