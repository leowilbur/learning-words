import BackgroundTasks
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    static let enabledKey = "notificationsEnabled"
    static let hourKey = "notificationHour"
    static let defaultHour = 8
    static let refreshTaskID = "com.leowilbur.learningwords.refresh"

    private static let categoryID = "LESSON"
    private static let speakWordsAction = "SPEAK_WORDS"
    private static let speakExamplesAction = "SPEAK_EXAMPLES"
    private static let dayKey = "day"
    private static let testRequestID = "test"
    private static let testDelay: TimeInterval = 5
    // iOS keeps at most 64 pending local notifications per app.
    private static let daysAhead = 30
    private static let refreshInterval: TimeInterval = 24 * 3600

    private let center = UNUserNotificationCenter.current()

    func configure() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true, Self.hourKey: Self.defaultHour])
        center.delegate = self
        let actions = [
            UNNotificationAction(identifier: Self.speakWordsAction, title: "Nghe \(WordSchedule.wordsPerDay) từ", options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "speaker.wave.2.fill")),
            UNNotificationAction(identifier: Self.speakExamplesAction, title: "Nghe từ và câu mẫu", options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "text.bubble.fill")),
        ]
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryID, actions: actions, intentIdentifiers: []),
        ])
    }

    /// Replaces the pending notifications with one daily lesson for each of the coming days.
    func refresh() async {
        center.removeAllPendingNotificationRequests()

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.enabledKey), !WordStore.all.isEmpty, await authorize() else { return }
        let hour = defaults.integer(forKey: Self.hourKey)
        let now = Date()
        let calendar = Calendar.current
        let today = WordSchedule.day(at: now)

        for offset in 0..<Self.daysAhead {
            let day = today + offset
            let date = WordSchedule.dayStart(day, near: now).addingTimeInterval(Double(hour) * 3600)
            guard date > now else { continue }
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                repeats: false
            )
            try? await center.add(UNNotificationRequest(identifier: "day-\(day)", content: content(forDay: day), trigger: trigger))
        }

        // Ask iOS to wake the app now and then so the batch is topped up without opening it.
        let task = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        task.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        try? BGTaskScheduler.shared.submit(task)
    }

    /// Sends the given day's lesson shortly after the tap. Returns false when notifications are not allowed.
    @discardableResult
    func sendTest(day: Int = WordSchedule.day(at: .now)) async -> Bool {
        guard await authorize() else { return false }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.testDelay, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: Self.testRequestID, content: content(forDay: day), trigger: trigger))
            return true
        } catch {
            return false
        }
    }

    private func authorize() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private func content(forDay day: Int) -> UNNotificationContent {
        let words = WordSchedule.words(forDay: day)
        let content = UNMutableNotificationContent()
        content.title = "\(words.count) từ mới hôm nay"
        content.subtitle = words.map(\.word).joined(separator: ", ")
        content.body = words.enumerated().map { index, word in
            let example = word.examples.first.map { "\n   “\($0.en)”" } ?? ""
            return "\(index + 1). \(word.word): \(word.meaning)\(example)"
        }
        .joined(separator: "\n")
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.threadIdentifier = Self.categoryID
        content.userInfo = [Self.dayKey: day]
        return content
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let day = response.notification.request.content.userInfo[Self.dayKey] as? Int else { return }
        let words = WordSchedule.words(forDay: day)

        switch response.actionIdentifier {
        case Self.speakWordsAction:
            await speakFromAction(WordSchedule.lessonSpeech(words, withExamples: false))
        case Self.speakExamplesAction:
            await speakFromAction(WordSchedule.lessonSpeech(words, withExamples: true))
        case UNNotificationDefaultActionIdentifier:
            await MainActor.run { AppModel.shared.showDay(day) }
        default:
            break
        }
    }

    // Action buttons run the app in the background; awaiting the speech keeps it alive until done.
    private func speakFromAction(_ text: String) async {
        let failure = await Speaker.shared.speak(text)
        let time = Date().formatted(date: .omitted, time: .standard)
        UserDefaults.standard.set("\(time) · \(failure ?? "OK")", forKey: Speaker.notificationLogKey)
    }
}
