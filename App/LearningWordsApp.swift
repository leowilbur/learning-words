import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    private static let favoritesKey = "favorites"

    @Published var slot = WordSchedule.slot(at: .now, intervalHours: WordSchedule.defaultIntervalHours)
    @Published var linkedWord: Word?
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
    @StateObject private var model = AppModel()
    @State private var tab = 0

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
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
                model.linkedWord = word
                tab = 0
                Task { await Speaker.shared.speak(word.word) }
            }
        }
    }
}
