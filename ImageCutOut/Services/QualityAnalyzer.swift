import Foundation
import CoreImage

struct QualityAnalyzer {
    static func analyze(mask: CIImage, originalSize: CGSize, settings: QualitySettings) -> AssetQualityMetrics {
        let resolutionOK = min(originalSize.width, originalSize.height) >= CGFloat(settings.minResolution)
            && max(originalSize.width, originalSize.height) <= CGFloat(settings.maxResolution)

        let ratio = originalSize.width / max(originalSize.height, 1)
        let aspectRatioOK = settings.allowedAspectRatios.contains { abs($0 - Double(ratio)) < 0.05 }

        let (edgeSmoothness, transparencyScore, confidence) = maskMetrics(mask)

        return AssetQualityMetrics(
            edgeSmoothnessScore: edgeSmoothness,
            transparencyArtifactsScore: transparencyScore,
            resolutionOK: resolutionOK,
            aspectRatioOK: aspectRatioOK,
            confidenceScore: confidence
        )
    }

    private static func maskMetrics(_ mask: CIImage) -> (Double, Double, Double) {
        guard let cgImage = ImageProcessing.makeCGImage(from: mask) else { return (0, 0, 0) }
        guard let data = cgImage.dataProvider?.data else { return (0, 0, 0) }
        let bytes = CFDataGetBytePtr(data)
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let components = cgImage.bitsPerPixel / 8

        var edgeEnergy: Double = 0
        var semiTransparent: Int = 0
        var opaqueCount: Int = 0
        var pixelCount: Int = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * components
                let alpha = Double(bytes?[offset + components - 1] ?? 0) / 255.0
                pixelCount += 1
                if alpha > 0.95 { opaqueCount += 1 }
                if alpha > 0.05 && alpha < 0.95 { semiTransparent += 1 }

                if x < width - 1 {
                    let offsetRight = y * bytesPerRow + (x + 1) * components
                    let alphaRight = Double(bytes?[offsetRight + components - 1] ?? 0) / 255.0
                    edgeEnergy += abs(alpha - alphaRight)
                }
            }
        }
        let smoothness = pixelCount > 0 ? max(0, 1 - edgeEnergy / Double(pixelCount)) : 0
        let transparencyArtifacts = pixelCount > 0 ? Double(semiTransparent) / Double(pixelCount) : 0
        let confidence = pixelCount > 0 ? Double(opaqueCount) / Double(pixelCount) : 0
        return (smoothness, transparencyArtifacts, confidence)
    }
}
