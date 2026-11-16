import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    private static let favoritesKey = "favorites"

    @Published var slot = WordSchedule.slot(at: .now, intervalHours: WordSchedule.defaultIntervalHours)
    @Published var linkedWord: Word?
    @Published var tab = 0
    @Published var favorites: Set<String> {
        didSet { UserDefaults.standard.set(Array(favorites), forKey: Self.favoritesKey) }
    }

    init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: Self.favoritesKey) ?? [])
    }

    var currentWord: Word? {
        linkedWord ?? WordSchedule.word(forSlot: slot)
    }

    func step(_ delta: Int) {
        linkedWord = nil
        slot += delta
    }

    func show(_ word: Word) {
        linkedWord = word
        tab = 0
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
                    .tabItem { Label("Từ mới", systemImage: "sparkles") }
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
                Task { await NotificationManager.shared.refresh() }
            }
        }
        .backgroundTask(.appRefresh(NotificationManager.refreshTaskID)) {
            await NotificationManager.shared.refresh()
        }
    }
}
