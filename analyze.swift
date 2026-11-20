import Foundation
import Vision
import CoreImage

let args = CommandLine.arguments
guard args.count > 1 else { exit(1) }
let path = args[1]
let url = URL(fileURLWithPath: path)
guard let ciImage = CIImage(contentsOf: url) else { exit(1) }

let request = VNRecognizeTextRequest { request, error in
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    for obs in observations {
        if let top = obs.topCandidates(1).first {
            let text = top.string
            if text.contains("0%") || text.contains("Distance") || text.contains("challenge") {
                print("Found '\(text)' at \(obs.boundingBox)")
            }
        }
    }
}
let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
try? handler.perform([request])
