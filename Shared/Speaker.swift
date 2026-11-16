import AVFoundation

@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    static let rateKey = "speechRate"
    static let defaultRate = 0.45
    static let widgetLogKey = "lastWidgetSpeak"
    static let notificationLogKey = "lastNotificationSpeak"

    private let synthesizer = AVSpeechSynthesizer()
    private var pending: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks with the US English system voice and returns once the utterance ends or is interrupted.
    /// Returns the audio session error, if any, so callers can surface why nothing was heard.
    @discardableResult
    func speak(_ text: String) async -> String? {
        synthesizer.stopSpeaking(at: .immediate)

        let session = AVAudioSession.sharedInstance()
        var failure: String?
        do {
            // Non-mixable on purpose: widget taps start audio while the app is in the background,
            // where iOS can refuse to activate a mixable session (e.g. .duckOthers).
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {
            failure = error.localizedDescription
        }

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
        return failure
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
