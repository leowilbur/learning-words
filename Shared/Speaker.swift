import AVFoundation

@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    static let rateKey = "speechRate"
    static let defaultRate = 0.45

    private let synthesizer = AVSpeechSynthesizer()
    private var pending: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks with the US English system voice and returns once the utterance ends or is interrupted.
    func speak(_ text: String) async {
        synthesizer.stopSpeaking(at: .immediate)

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        let stored = UserDefaults.standard.double(forKey: Self.rateKey)
        utterance.rate = Float(stored > 0 ? stored : Self.defaultRate)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            pending[ObjectIdentifier(utterance)] = continuation
            synthesizer.speak(utterance)
        }

        if pending.isEmpty {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func finish(_ id: ObjectIdentifier) {
        pending.removeValue(forKey: id)?.resume()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(id) }
    }
}
