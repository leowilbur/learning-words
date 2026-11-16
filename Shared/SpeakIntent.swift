import AppIntents

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
        await Speaker.shared.speak(text)
        return .result()
    }
}
