import CoreGraphics
import SensitiveContentAnalysis
import Vision

/// Recognized text is the input for both the sensitivity rules and the context actions.
nonisolated enum TextRecognizer {
    /// `perform` blocks its thread and Vision waits inside it for other threads. Run from
    /// tasks, several recognitions at once took every thread of the Swift concurrency pool
    /// and Vision deadlocked. A serial queue of its own keeps them one at a time and off that pool.
    private static let queue = DispatchQueue(label: "TextRecognizer", qos: .utility)

    static func text(in image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            queue.async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                try? VNImageRequestHandler(cgImage: image).perform([request])
                let text = (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
        }
    }
}

nonisolated enum SensitivityCheck {
    /// Cheapest first: text rules, then the system analyzer. The model's own flag
    /// arrives separately and is merged by the caller.
    static func assess(text: String, image: CGImage) async -> Sensitivity {
        let byRules = SensitivityRules.classify(text)
        if byRules != .none { return byRules }

        // The analyzer needs the Sensitive Content Analysis entitlement, which a personal
        // development team cannot have; without it the policy is `.disabled` and this step
        // is skipped. With the entitlement it also needs Sensitive Content Warning to be
        // turned on in Settings; for adults that is off by default.
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else { return .none }
        let isSensitive = (try? await analyzer.analyzeImage(image).isSensitive) ?? false
        return isSensitive ? .explicit : .none
    }
}
