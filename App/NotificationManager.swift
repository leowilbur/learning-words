import BackgroundTasks
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    static let enabledKey = "notificationsEnabled"
    static let startHourKey = "notificationStartHour"
    static let endHourKey = "notificationEndHour"
    static let refreshTaskID = "com.leowilbur.learningwords.refresh"

    private static let categoryID = "WORD"
    private static let speakWordAction = "SPEAK_WORD"
    private static let speakExamplesAction = "SPEAK_EXAMPLES"
    private static let indexKey = "index"
    private static let requestPrefix = "word-"
    private static let testRequestID = "test"
    private static let testDelay: TimeInterval = 5
    // iOS keeps at most 64 pending local notifications per app.
    private static let maxPending = 60
    private static let lookaheadSlots = 24 * 7
    private static let refreshInterval: TimeInterval = 12 * 3600

    private let center = UNUserNotificationCenter.current()

    func configure() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true, Self.startHourKey: 7, Self.endHourKey: 22])
        center.delegate = self
        let actions = [
            UNNotificationAction(identifier: Self.speakWordAction, title: "Nghe từ", options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "speaker.wave.2.fill")),
            UNNotificationAction(identifier: Self.speakExamplesAction, title: "Nghe từ và câu mẫu", options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "text.bubble.fill")),
        ]
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryID, actions: actions, intentIdentifiers: []),
        ])
    }

    /// Replaces the pending hourly notifications with the next batch inside the active hours.
    func refresh() async {
        let stale = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(Self.requestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.enabledKey), !WordStore.all.isEmpty, await authorize() else { return }
        let start = defaults.integer(forKey: Self.startHourKey)
        let end = defaults.integer(forKey: Self.endHourKey)
        let hours = WordSchedule.defaultIntervalHours
        let now = Date()
        let calendar = Calendar.current
        let current = WordSchedule.slot(at: now, intervalHours: hours)
        var scheduled = 0

        for offset in 1...Self.lookaheadSlots where scheduled < Self.maxPending {
            let slot = current + offset
            let date = WordSchedule.slotStart(slot, intervalHours: hours, near: now)
            let hour = calendar.component(.hour, from: date)
            let active = start <= end ? (start...end).contains(hour) : (hour >= start || hour <= end)
            guard active, let word = WordSchedule.word(forSlot: slot) else { continue }
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                repeats: false
            )
            let request = UNNotificationRequest(identifier: "\(Self.requestPrefix)\(slot)", content: content(for: word), trigger: trigger)
            try? await center.add(request)
            scheduled += 1
        }

        // The batch only covers a few days, so ask iOS to wake the app and top it up.
        let task = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        task.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        try? BGTaskScheduler.shared.submit(task)
    }

    func sendTest() async {
        let hours = WordSchedule.defaultIntervalHours
        guard await authorize(),
              let word = WordSchedule.word(forSlot: WordSchedule.slot(at: .now, intervalHours: hours)) else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.testDelay, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.testRequestID, content: content(for: word), trigger: trigger))
    }

    private func authorize() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private func content(for word: Word) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(word.word)  \(word.ipa)"
        content.subtitle = "\(word.meaning) (\(word.pos))"
        content.body = word.examples.map { "• \($0.en)" }.joined(separator: "\n")
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.threadIdentifier = Self.categoryID
        if let index = WordStore.all.firstIndex(of: word) {
            content.userInfo = [Self.indexKey: index]
        }
        return content
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let index = response.notification.request.content.userInfo[Self.indexKey] as? Int,
              WordStore.all.indices.contains(index) else { return }
        let word = WordStore.all[index]

        switch response.actionIdentifier {
        case Self.speakWordAction:
            await speakFromAction(word.word)
        case Self.speakExamplesAction:
            await speakFromAction(([word.word] + word.examples.map(\.en)).joined(separator: ". "))
        case UNNotificationDefaultActionIdentifier:
            await MainActor.run { AppModel.shared.show(word) }
            await Speaker.shared.speak(word.word)
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
