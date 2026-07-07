import UIKit
import Vision

public struct OCRReceiptResult {
    public let amount: String?
    public let date: String?
    public let vendor: String?
    public let receiptNumber: String?

    public init(amount: String? = nil, date: String? = nil, vendor: String? = nil, receiptNumber: String? = nil) {
        self.amount = amount
        self.date = date
        self.vendor = vendor
        self.receiptNumber = receiptNumber
    }
}

public struct OCRService {
    public static func extractReceiptInfo(from image: UIImage, completion: @escaping (OCRReceiptResult?) -> Void) {
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

            var amount: String?
            var date: String?
            var vendor: String?
            var receiptNumber: String?

            let amountPattern = try? NSRegularExpression(pattern: "(?:^|\\s)(?:₹|Rs\\.?|INR|\\$|€|£)?\\s*\\d+[\\.\\,]\\d{2}\\b")
            let datePattern = try? NSRegularExpression(pattern: "\\b\\d{1,2}[/\\-\\.]\\d{1,2}[/\\-\\.]\\d{2,4}\\b")
            let receiptNumPattern = try? NSRegularExpression(pattern: "(?:receipt|inv|bill|challan)[:\\s]*(\\w+[/\\-]?\\w+)", options: [.caseInsensitive])

            for text in recognizedStrings {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                if amount == nil {
                    let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
                    if let matches = amountPattern?.matches(in: trimmed, range: nsRange), !matches.isEmpty,
                       let range = Range(matches[0].range(at: 0), in: trimmed) {
                        amount = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
                    }
                }

                if date == nil {
                    let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
                    if let matches = datePattern?.matches(in: trimmed, range: nsRange), !matches.isEmpty,
                       let range = Range(matches[0].range(at: 0), in: trimmed) {
                        date = String(trimmed[range])
                    }
                }

                if receiptNumber == nil {
                    let nsRange = NSRange(text.startIndex..., in: text)
                    if let matches = receiptNumPattern?.matches(in: text, range: nsRange), !matches.isEmpty,
                       matches[0].numberOfRanges > 1,
                       let range = Range(matches[0].range(at: 1), in: text) {
                        receiptNumber = String(text[range])
                    }
                }

                if vendor == nil && text.count > 3 && text.count < 60 {
                    vendor = text
                }

                if amount != nil && date != nil && receiptNumber != nil { break }
            }

            if amount != nil || date != nil || vendor != nil || receiptNumber != nil {
                completion(OCRReceiptResult(amount: amount, date: date, vendor: vendor, receiptNumber: receiptNumber))
            } else {
                completion(nil)
            }
        }

        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }

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

            for text in recognizedStrings {
                let cleaned = text.replacingOccurrences(of: "%", with: "")
                    .replacingOccurrences(of: "percent", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

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
