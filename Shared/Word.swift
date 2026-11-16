import Foundation

struct WordExample: Codable, Hashable {
    let en: String
    let vi: String
}

struct Word: Codable, Hashable, Identifiable {
    let word: String
    let ipa: String
    let pos: String
    let meaning: String
    let examples: [WordExample]

    var id: String { word }
}

enum WordStore {
    static let all: [Word] = {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Word].self, from: data) else { return [] }
        return words
    }()
}

enum WordSchedule {
    static let defaultIntervalHours = 1
    static let deepLinkScheme = "learningwords"
    // Coprime with any realistic word count, so slots walk the whole list in a scattered order.
    private static let stride = 7919

    static func slot(at date: Date, intervalHours: Int) -> Int {
        let local = date.timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT(for: date))
        return Int(local / Double(intervalHours * 3600))
    }

    static func slotStart(_ slot: Int, intervalHours: Int, near date: Date) -> Date {
        let local = Double(slot * intervalHours * 3600)
        return Date(timeIntervalSince1970: local - Double(TimeZone.current.secondsFromGMT(for: date)))
    }

    static func index(forSlot slot: Int) -> Int {
        let count = WordStore.all.count
        guard count > 0 else { return 0 }
        return ((slot % count) * (stride % count) % count + count) % count
    }

    static func word(forSlot slot: Int) -> Word? {
        let words = WordStore.all
        return words.isEmpty ? nil : words[index(forSlot: slot)]
    }

    static func deepLink(for word: Word) -> URL? {
        guard let index = WordStore.all.firstIndex(of: word) else { return nil }
        return URL(string: "\(deepLinkScheme)://word/\(index)")
    }

    static func word(from url: URL) -> Word? {
        guard url.scheme == deepLinkScheme, let index = Int(url.lastPathComponent),
              WordStore.all.indices.contains(index) else { return nil }
        return WordStore.all[index]
    }
}
