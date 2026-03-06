import CoreGraphics
import Vision

struct RecognizedTextBlock {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

enum OCRError: Error {
    case noResults
    case recognitionFailed(Error)
}

enum OCRService {
    static func recognize(in image: CGImage) async throws -> [RecognizedTextBlock] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }

                let blocks: [RecognizedTextBlock] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    guard candidate.confidence >= 0.3 else { return nil }
                    return RecognizedTextBlock(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }

                // Sort top-to-bottom (descending Y in Vision coords = bottom-left origin),
                // then left-to-right within the same row
                let sorted = blocks.sorted { lhs, rhs in
                    let yDiff = rhs.boundingBox.minY - lhs.boundingBox.minY
                    if abs(yDiff) > 0.01 { return yDiff < 0 } // higher Y = higher on screen
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }

                continuation.resume(returning: sorted)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }
}
