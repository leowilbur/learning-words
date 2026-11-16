import AppIntents
import Foundation

// AudioPlaybackIntent makes iOS run this in the app process (in the background),
// which is the only place a widget tap is allowed to produce sound.
struct SpeakIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Phát âm"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Text")
    var text: String

    init() {}

    init(text: String) {
        self.text = text
    }

    func perform() async throws -> some IntentResult {
        // Audio is only possible in the app process; the widget extension's copy must stay silent.
        guard !Bundle.main.bundlePath.hasSuffix(".appex") else { return .result() }
        let failure = await Speaker.shared.speak(text)
        let time = Date().formatted(date: .omitted, time: .standard)
        UserDefaults.standard.set("\(time) · \(failure ?? "OK")", forKey: Speaker.widgetLogKey)
        return .result()
    }
}
