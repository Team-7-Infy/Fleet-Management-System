import UIKit
import Vision

public struct OCRService {
    /// Performs text recognition (OCR) on the provided image and scans for a fuel percentage value (0-100)
    public static func extractFuelLevel(from image: UIImage, completion: @escaping (Int?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            
            // Look for any string containing a number between 0 and 100
            for text in recognizedStrings {
                // Clean up string: remove spaces and percentage signs
                let cleaned = text.replacingOccurrences(of: "%", with: "")
                    .replacingOccurrences(of: "percent", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Regular expression to match an integer between 0 and 100
                let pattern = "\\b(100|[0-9]{1,2})\\b"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                    if let range = Range(match.range(at: 1), in: cleaned),
                       let fuelVal = Int(cleaned[range]) {
                        completion(fuelVal)
                        return
                    }
                }
            }
            completion(nil)
        }
        
        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }
}
