import Foundation
@preconcurrency import Vision
@preconcurrency import CoreML
import CoreImage

protocol SegmentationModel {
    var modelName: String { get }
    var isAvailable: Bool { get }
    func predictMask(for image: CIImage) async throws -> CIImage?
}

final class CoreMLSegmentationModel: SegmentationModel {
    let modelName: String
    private let visionModel: VNCoreMLModel

    var isAvailable: Bool { true }

    init?(modelName: String) {
        self.modelName = modelName
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") ??
                Bundle.main.url(forResource: modelName, withExtension: "mlpackage") else {
            return nil
        }
        do {
            let model = try MLModel(contentsOf: modelURL)
            self.visionModel = try VNCoreMLModel(for: model)
        } catch {
            return nil
        }
    }

    func predictMask(for image: CIImage) async throws -> CIImage? {
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])
        guard let result = request.results?.first else { return nil }
        if let pixelObservation = result as? VNPixelBufferObservation {
            return CIImage(cvPixelBuffer: pixelObservation.pixelBuffer)
        }
        if let featureObservation = result as? VNCoreMLFeatureValueObservation,
           let buffer = featureObservation.featureValue.imageBufferValue {
            return CIImage(cvPixelBuffer: buffer)
        }
        return nil
    }
}

final class StubSegmentationModel: SegmentationModel {
    let modelName: String = "Stub"
    var isAvailable: Bool { false }

    func predictMask(for image: CIImage) async throws -> CIImage? {
        CIImage(color: .white).cropped(to: image.extent)
    }
}

final class SegmentationModelFactory {
    static func loadModel(named name: String?) -> SegmentationModel {
        if let name = name, let model = CoreMLSegmentationModel(modelName: name) {
            return model
        }
        return StubSegmentationModel()
    }
}
