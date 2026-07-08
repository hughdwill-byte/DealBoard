import Vision
import UIKit

/// One recognised line plus the height of its bounding box (0–1, fraction of the
/// image). Taller boxes ≈ visually bigger text, which we use to guess the title.
struct OCRLine {
    let text: String
    let height: CGFloat
}

/// On-device text recognition via the Vision framework. Fully offline — no
/// network, no server. Returns [] if the image can't be read or has no text.
enum OCRService {
    static func recognize(in image: UIImage) async -> [OCRLine] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            // .accurate + language correction gives the best result on menu-board
            // style photos; it's slower but runs comfortably on-device.
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { obs -> OCRLine? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return nil }
                    return OCRLine(text: trimmed, height: obs.boundingBox.height)
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

private extension UIImage {
    /// Vision wants a CGImagePropertyOrientation; bridge from UIImage.Orientation
    /// so rotated camera photos are read the right way up.
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
