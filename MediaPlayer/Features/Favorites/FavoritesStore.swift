import Foundation
import Observation

struct FavoriteSource: Codable, Identifiable {
    let url: URL
    let title: String

    var id: URL { url }
}

@MainActor @Observable
final class FavoritesStore {
    private(set) var sources: [FavoriteSource]

    private let defaults: UserDefaults
    private let key = "mediaPlayer.favoriteSources"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([FavoriteSource].self, from: data) {
            sources = saved
        } else {
            sources = []
        }
    }

    func contains(_ url: URL) -> Bool {
        sources.contains { $0.url == url }
    }

    func add(_ url: URL, title: String) {
        guard !contains(url) else { return }
        sources.append(FavoriteSource(url: url, title: title))
        save()
    }

    func remove(_ url: URL) {
        sources.removeAll { $0.url == url }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        defaults.set(data, forKey: key)
    }
}
