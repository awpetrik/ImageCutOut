import Foundation
@preconcurrency import Vision
import CoreImage

struct OCRService {
    static func recognizeText(from image: CIImage) async -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
            let results = request.results ?? []
            return results.compactMap { $0.topCandidates(1).first?.string }
        } catch {
            return []
        }
    }
}
