import SwiftUI

private func speak(_ text: String) {
    Task { await Speaker.shared.speak(text) }
}

struct WordDetail: View {
    @EnvironmentObject private var model: AppModel
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(word.word)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                Spacer()
                Button { model.toggleFavorite(word) } label: {
                    Image(systemName: model.favorites.contains(word.id) ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
            }
            Button { speak(word.word) } label: {
                Label("\(word.ipa) · \(word.pos)", systemImage: "speaker.wave.2.fill")
                    .font(.system(.body, design: .monospaced))
            }
            Text(word.meaning)
                .font(.title3.weight(.medium))

            ForEach(word.examples, id: \.self) { example in
                Button { speak(example.en) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.en)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(example.vi)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .multilineTextAlignment(.leading)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding()
    }
}

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    private var words: [Word] { WordSchedule.words(forDay: model.day) }

    private var title: String {
        guard model.day != WordSchedule.day(at: .now) else { return "\(WordSchedule.wordsPerDay) từ hôm nay" }
        return WordSchedule.dayStart(model.day, near: .now).formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        NavigationStack(path: $model.path) {
            List(words) { word in
                HStack(spacing: 12) {
                    Button { speak(word.word) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.body)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.borderless)
                    NavigationLink(value: word) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(word.word).font(.headline)
                                Text(word.ipa)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Text(word.meaning).font(.subheadline)
                            if let example = word.examples.first {
                                Text(example.en)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .overlay {
                if words.isEmpty {
                    ContentUnavailableView("Chưa có dữ liệu từ vựng", systemImage: "book.closed")
                }
            }
            .navigationDestination(for: Word.self) { word in
                ScrollView { WordDetail(word: word) }
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { model.day -= 1 } label: { Label("Hôm trước", systemImage: "chevron.left") }
                    Spacer()
                    Button { speak(WordSchedule.lessonSpeech(words, withExamples: true)) } label: {
                        Label("Nghe cả bài", systemImage: "play.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    Spacer()
                    Button { model.day += 1 } label: { Label("Hôm sau", systemImage: "chevron.right") }
                }
            }
        }
    }
}

struct WordListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var favoritesOnly = false

    private var words: [Word] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return WordStore.all.filter { word in
            (!favoritesOnly || model.favorites.contains(word.id))
                && (needle.isEmpty || word.word.lowercased().contains(needle) || word.meaning.lowercased().contains(needle))
        }
    }

    var body: some View {
        NavigationStack {
            List(words) { word in
                NavigationLink {
                    ScrollView { WordDetail(word: word) }
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(word.word).font(.headline)
                        Text(word.meaning).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if words.isEmpty {
                    ContentUnavailableView("Không có từ nào", systemImage: "magnifyingglass")
                }
            }
            .searchable(text: $query, prompt: "Tìm từ hoặc nghĩa")
            .navigationTitle("Danh sách (\(words.count))")
            .toolbar {
                Button { favoritesOnly.toggle() } label: {
                    Image(systemName: favoritesOnly ? "star.fill" : "star")
                }
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage(Speaker.rateKey) private var rate = Speaker.defaultRate
    @AppStorage(Speaker.widgetLogKey) private var widgetLog = "Chưa có lần nào"
    @AppStorage(Speaker.notificationLogKey) private var notificationLog = "Chưa có lần nào"
    @AppStorage(NotificationManager.enabledKey) private var notificationsEnabled = true
    @AppStorage(NotificationManager.hourKey) private var notificationHour = NotificationManager.defaultHour
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Slider(value: $rate, in: 0.3...0.6) {
                        Text("Tốc độ đọc")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                    Button("Nghe thử") { speak("Let's grab a coffee sometime.") }
                } header: {
                    Text("Tốc độ đọc")
                } footer: {
                    Text("Áp dụng cho cả app và widget.")
                }
                Section {
                    Toggle("Bài học \(WordSchedule.wordsPerDay) từ mỗi ngày", isOn: $notificationsEnabled)
                    if notificationsEnabled {
                        Picker("Giờ nhận", selection: $notificationHour) {
                            ForEach(0..<24, id: \.self) { Text("\($0):00").tag($0) }
                        }
                        Button("Gửi thử sau 5 giây") {
                            Task { await NotificationManager.shared.sendTest() }
                        }
                    }
                } header: {
                    Text("Thông báo")
                } footer: {
                    Text("Giữ lên thông báo để xem đủ bài và hiện nút Nghe \(WordSchedule.wordsPerDay) từ, Nghe từ và câu mẫu. Chạm vào thông báo để mở bài học hôm đó. Nếu không thấy thông báo, bật Cho phép trong Cài đặt > Thông báo > Từ Mới.")
                }
                .onChange(of: [notificationsEnabled ? 1 : 0, notificationHour]) {
                    Task { await NotificationManager.shared.refresh() }
                }
                Section("Widget") {
                    Text("Widget lần lượt hiện \(WordSchedule.wordsPerDay) từ của hôm nay, đổi mỗi giờ.")
                    Text("Chạm loa hoặc một câu để nghe ngay. Chạm chỗ khác để mở app và nghe từ đó.")
                    Text("Màn hình khóa: giữ lên màn hình khóa, chọn Tùy chỉnh, rồi thêm tiện ích Từ Mới vào ô dưới đồng hồ.")
                    Text("Để giọng đọc hay hơn: Cài đặt > Trợ năng > Nội dung được đọc > Giọng nói > Tiếng Anh, tải một giọng Mỹ chất lượng cao.")
                }
                .font(.subheadline)
                Section("Chẩn đoán") {
                    LabeledContent("Phiên bản", value: version)
                    LabeledContent("Lần bấm loa gần nhất từ widget", value: widgetLog)
                    LabeledContent("Lần nghe gần nhất từ thông báo", value: notificationLog)
                }
                .font(.subheadline)
            }
            .navigationTitle("Cài đặt")
        }
    }
}
