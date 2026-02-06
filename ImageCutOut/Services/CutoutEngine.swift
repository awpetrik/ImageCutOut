import Foundation
import CoreImage

struct CutoutResult {
    var outputImage: CIImage
    var maskImage: CIImage
    var shadowLayer: CIImage?
    var confidenceScore: Double
    var warnings: [String]
}

actor CutoutEngine {
    private var model: SegmentationModel
    private let logger: LogStore

    init(modelName: String? = nil, logger: LogStore) {
        self.model = SegmentationModelFactory.loadModel(named: modelName)
        self.logger = logger
    }

    func updateModel(name: String?) {
        model = SegmentationModelFactory.loadModel(named: name)
    }

    func process(url: URL, settings: CutoutSettings, preserveEXIF: Bool) async throws -> CutoutResult {
        let ciImage = try ImageProcessing.loadCIImage(from: url)
        let baseImage = settings.autoWhiteBalance ? ImageProcessing.autoAdjust(image: ciImage) : ciImage

        var segmentationImage = baseImage
        var scaleFactor: CGFloat = 1.0
        let maxDimension = max(baseImage.extent.width, baseImage.extent.height)
        if maxDimension > 4096 {
            scaleFactor = 4096 / maxDimension
            segmentationImage = baseImage.transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        }

        var warnings: [String] = []
        let mask = try await model.predictMask(for: segmentationImage)
        var maskImage = mask ?? CIImage(color: .white).cropped(to: baseImage.extent)
        if !model.isAvailable {
            warnings.append("Segmentation model not available. Output needs review.")
        }
        if scaleFactor != 1.0 {
            let inverse = 1.0 / scaleFactor
            maskImage = maskImage
                .transformed(by: CGAffineTransform(scaleX: inverse, y: inverse))
                .cropped(to: baseImage.extent)
        }

        if settings.despeckle {
            maskImage = ImageProcessing.despeckle(mask: maskImage)
        }

        let qualityFactor = max(0.1, min(1.0, settings.edgeQuality))
        var feather = settings.featherRadius * (1.0 + (1.0 - qualityFactor))
        if settings.hairEdgeMode { feather = max(feather, 4) }
        if settings.glassHandlingMode { feather = max(feather, 3) }
        maskImage = ImageProcessing.feather(mask: maskImage, radius: feather)
        let baseThreshold = settings.glassHandlingMode ? settings.threshold * 0.85 : settings.threshold
        let thresholdValue = baseThreshold * (0.9 + 0.2 * qualityFactor)
        maskImage = ImageProcessing.threshold(mask: maskImage, value: thresholdValue)
        if settings.edgeSmoothing {
            maskImage = ImageProcessing.smoothEdges(mask: maskImage)
        }

        let coverage = maskImage.coverageRatio()
        let confidence = min(1.0, max(0.05, Double(coverage)))
        if confidence < settings.confidenceThreshold {
            warnings.append("Low confidence segmentation result (\(String(format: "%.2f", confidence))).")
        }

        var output = ImageProcessing.applyMask(image: baseImage, mask: maskImage)
        var maskForOutput = maskImage
        if settings.autoCrop {
            let bounding = maskImage.boundingBoxOfVisiblePixels(threshold: 0.1)
            if !bounding.isNull {
                let padded = bounding.insetBy(dx: -bounding.width * CGFloat(settings.paddingPercent / 100),
                                              dy: -bounding.height * CGFloat(settings.paddingPercent / 100))
                let cropRect = padded.intersection(baseImage.extent)
                output = output.cropped(to: cropRect)
                maskForOutput = maskImage.cropped(to: cropRect)
            }
        } else {
            output = ImageProcessing.addPadding(image: output, percent: settings.paddingPercent)
            maskForOutput = ImageProcessing.addPadding(image: maskImage, percent: settings.paddingPercent)
        }

        if settings.backgroundOption == .white {
            output = ImageProcessing.addWhiteBackground(image: output)
        }

        var shadowLayer: CIImage?
        if settings.shadowMode != .none {
            output = ImageProcessing.addShadow(image: output, radius: settings.shadowMode == .soft ? 8 : 14)
            if settings.preserveShadowLayer {
                shadowLayer = ImageProcessing.addShadow(image: output, radius: 12)
            }
        }

        let objectPercent = coverage * 100
        if objectPercent < settings.minObjectSizePercent {
            warnings.append("Detected object below minimum size threshold.")
        }

        logger.log(.info, "Processed \(url.lastPathComponent)")
        return CutoutResult(outputImage: output, maskImage: maskForOutput, shadowLayer: shadowLayer, confidenceScore: confidence, warnings: warnings)
    }
}

extension CIImage {
    func coverageRatio() -> CGFloat {
        guard let cgImage = ImageProcessing.makeCGImage(from: self) else { return 0 }
        guard let data = cgImage.dataProvider?.data else { return 0 }
        let bytes = CFDataGetBytePtr(data)
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let components = cgImage.bitsPerPixel / 8
        var count: Int = 0
        var opaque: Int = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * components
                let alpha = bytes?[offset + components - 1] ?? 0
                count += 1
                if alpha > 20 { opaque += 1 }
            }
        }
        guard count > 0 else { return 0 }
        return CGFloat(opaque) / CGFloat(count)
    }
}
