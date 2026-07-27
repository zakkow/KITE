import Foundation

enum PreferencesStore {
    static func save(_ prefs: UserPreferences) {
        guard let data = try? JSONEncoder().encode(prefs),
              (try? JSONDecoder().decode(UserPreferences.self, from: data)) != nil else {
            return // verification failed — do not write
        }
        SharedStore.defaults?.set(data, forKey: SharedStore.Keys.userPreferences)
    }

    static func load() -> UserPreferences {
        guard let data = SharedStore.defaults?.data(forKey: SharedStore.Keys.userPreferences),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences.default
        }
        return prefs
    }
}
