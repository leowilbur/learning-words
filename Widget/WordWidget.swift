import AppIntents
import SwiftUI
import WidgetKit

struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word?
}

struct WordProvider: TimelineProvider {
    private static let entriesPerTimeline = 12
    private static let hours = WordSchedule.defaultIntervalHours

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, word: WordStore.all.first)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(WordEntry(date: .now, word: WordSchedule.word(forSlot: WordSchedule.slot(at: .now, intervalHours: Self.hours))))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let now = Date()
        let first = WordSchedule.slot(at: now, intervalHours: Self.hours)
        let entries = (0..<Self.entriesPerTimeline).map { offset -> WordEntry in
            let slot = first + offset
            let date = offset == 0 ? now : WordSchedule.slotStart(slot, intervalHours: Self.hours, near: now)
            return WordEntry(date: date, word: WordSchedule.word(forSlot: slot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        if let word = entry.word {
            Group {
                switch family {
                case .accessoryInline:
                    Text("\(word.word) · \(word.meaning)")
                case .accessoryRectangular:
                    lockScreen(word)
                default:
                    content(word)
                }
            }
            .widgetURL(WordSchedule.deepLink(for: word))
        } else {
            Text("Chưa có dữ liệu từ vựng")
                .font(.footnote)
        }
    }

    private var exampleCount: Int {
        switch family {
        case .systemSmall: return 0
        case .systemMedium: return 2
        default: return 3
        }
    }

    private func lockScreen(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(word.word)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(word.ipa)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.8)
                Spacer(minLength: 2)
                Button(intent: SpeakIntent(text: word.word)) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            Text(word.meaning)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let example = word.examples.first {
                Text(example.en)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func content(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(word.word)
                    .font(.system(size: family == .systemSmall ? 24 : 26, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 4)
                Button(intent: SpeakIntent(text: word.word)) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(7)
                        .background(.white.opacity(0.22), in: Circle())
                }
                .buttonStyle(.plain)
            }
            Text(word.ipa)
                .font(.system(size: 13, design: .monospaced))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(word.meaning)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(family == .systemSmall ? 3 : 1)
                .minimumScaleFactor(0.8)

            ForEach(word.examples.prefix(exampleCount), id: \.self) { example in
                Button(intent: SpeakIntent(text: example.en)) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("“\(example.en)”")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(family == .systemLarge ? 2 : 1)
                            .minimumScaleFactor(0.75)
                        if family == .systemLarge {
                            Text(example.vi)
                                .font(.system(size: 12))
                                .opacity(0.8)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }
}

@main
struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HourlyWordWidget", provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.31, green: 0.27, blue: 0.9), Color(red: 0.05, green: 0.65, blue: 0.91)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Từ mới")
        .description("Từ vựng và câu giao tiếp kiểu Mỹ. Chạm loa hoặc câu để nghe.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}
