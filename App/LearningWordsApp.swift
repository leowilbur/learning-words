import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    private static let favoritesKey = "favorites"

    @Published var day = WordSchedule.day(at: .now)
    @Published var path: [Word] = []
    @Published var tab = 0
    private var lastToday = WordSchedule.day(at: .now)
    private var pinned = false
    @Published var favorites: Set<String> {
        didSet { UserDefaults.standard.set(Array(favorites), forKey: Self.favoritesKey) }
    }

    init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: Self.favoritesKey) ?? [])
    }

    func show(_ word: Word) {
        path = [word]
        tab = 0
    }

    func showDay(_ day: Int) {
        pinned = true
        self.day = day
        path = []
        tab = 0
    }

    /// Moves to the new day's lesson when the date changed since the app was last active,
    /// unless a notification just asked for a specific day.
    func rollOverIfNeeded() {
        let today = WordSchedule.day(at: .now)
        if today != lastToday {
            lastToday = today
            if !pinned { day = today }
        }
        pinned = false
    }

    func toggleFavorite(_ word: Word) {
        if favorites.contains(word.id) {
            favorites.remove(word.id)
        } else {
            favorites.insert(word.id)
        }
    }
}

@main
struct LearningWordsApp: App {
    @StateObject private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $model.tab) {
                TodayView()
                    .tabItem { Label("Hôm nay", systemImage: "sparkles") }
                    .tag(0)
                WordListView()
                    .tabItem { Label("Danh sách", systemImage: "list.bullet") }
                    .tag(1)
                SettingsView()
                    .tabItem { Label("Cài đặt", systemImage: "gearshape") }
                    .tag(2)
            }
            .environmentObject(model)
            .onOpenURL { url in
                guard let word = WordSchedule.word(from: url) else { return }
                model.show(word)
                Task { await Speaker.shared.speak(word.word) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                model.rollOverIfNeeded()
                Task { await NotificationManager.shared.refresh() }
            }
        }
        .backgroundTask(.appRefresh(NotificationManager.refreshTaskID)) {
            await NotificationManager.shared.refresh()
        }
    }
}
