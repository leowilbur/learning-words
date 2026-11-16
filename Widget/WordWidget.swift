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
                case .systemSmall:
                    small(word)
                case .systemMedium:
                    medium(word)
                default:
                    large(word)
                }
            }
            .widgetURL(WordSchedule.deepLink(for: word))
        } else {
            Text("Chưa có dữ liệu từ vựng")
                .font(.footnote)
        }
    }

    private func speakerButton(_ text: String, size: CGFloat) -> some View {
        Button(intent: SpeakIntent(text: text)) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .background(.white.opacity(0.24), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.white.opacity(0.2), in: Capsule())
    }

    private func title(_ word: Word, size: CGFloat) -> some View {
        Text(word.word)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func ipa(_ word: Word, size: CGFloat) -> some View {
        Text(word.ipa)
            .font(.system(size: size, design: .monospaced))
            .opacity(0.85)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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

    private func small(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title(word, size: 26)
            ipa(word, size: 12)
            Text(word.meaning)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            HStack {
                badge(word.pos)
                Spacer(minLength: 0)
                speakerButton(word.word, size: 34)
            }
        }
        .foregroundStyle(.white)
    }

    private func medium(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                title(word, size: 26)
                ipa(word, size: 12)
                Spacer(minLength: 4)
                speakerButton(word.word, size: 32)
            }
            HStack(spacing: 6) {
                badge(word.pos)
                Text(word.meaning)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            ForEach(word.examples.prefix(2), id: \.self) { example in
                Button(intent: SpeakIntent(text: example.en)) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14))
                        Text(example.en)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
    }

    private func large(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                title(word, size: 34)
                Spacer(minLength: 4)
                speakerButton(word.word, size: 40)
            }
            HStack(spacing: 8) {
                ipa(word, size: 14)
                badge(word.pos)
            }
            Text(word.meaning)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            ForEach(word.examples, id: \.self) { example in
                Button(intent: SpeakIntent(text: example.en)) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(example.en)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            Text(example.vi)
                                .font(.system(size: 12))
                                .opacity(0.8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
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
