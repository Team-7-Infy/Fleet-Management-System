import Foundation
import AVFoundation
import Combine
import CoreLocation

final class VoiceGuidanceManager: NSObject, ObservableObject {
    @Published var currentInstruction: String = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var stepInstructions: [String] = []
    private var stepCumulativeDistances: [CLLocationDistance] = []
    private var totalDistance: CLLocationDistance = 0
    private var currentStepIndex: Int = -1
    private var hasAnnouncedFirstStep = false
    private var lastDeviationAnnouncement: Date?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func configure(instructions: [String], distances: [CLLocationDistance]) {
        var filteredInstructions: [String] = []
        var cumulativeDistances: [CLLocationDistance] = []
        var total: CLLocationDistance = 0

        for (instruction, distance) in zip(instructions, distances) {
            let trimmed = instruction.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            filteredInstructions.append(trimmed)
            total += distance
            cumulativeDistances.append(total)
        }

        stepInstructions = filteredInstructions
        stepCumulativeDistances = cumulativeDistances
        totalDistance = total
        currentStepIndex = -1
        hasAnnouncedFirstStep = false
    }

    func update(remainingDistance: CLLocationDistance, nearestCoordIdx: Int) {
        let traveled = max(0, totalDistance - remainingDistance)

        for (index, cumulative) in stepCumulativeDistances.enumerated() {
            if traveled <= cumulative {
                if index != currentStepIndex || !hasAnnouncedFirstStep {
                    currentStepIndex = index
                    hasAnnouncedFirstStep = true
                    speak(stepInstructions[index])
                }
                return
            }
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func announceDeviation(distanceMeters: Double) {
        if let last = lastDeviationAnnouncement, Date().timeIntervalSince(last) < 30 {
            return
        }
        lastDeviationAnnouncement = Date()

        let rounded = (round(distanceMeters / 10) * 10)
        let text = "You have deviated from the planned route by \(Int(rounded)) meters. Please return to the route."
        speak(text)
    }

    private func speak(_ text: String) {
        currentInstruction = text
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}

extension VoiceGuidanceManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        currentInstruction = utterance.speechString
    }
}
