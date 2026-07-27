import Foundation

enum PreferencesStore {
    static func save(_ prefs: UserPreferences) {
        guard let data = try? JSONEncoder().encode(prefs),
              (try? JSONDecoder().decode(UserPreferences.self, from: data)) != nil else {
            return // verification failed — do not write
        }
        SharedStore.setSharedData(data, forKey: SharedStore.Keys.userPreferences)
    }

    static func load() -> UserPreferences {
        let rawData = SharedStore.getSharedData(forKey: SharedStore.Keys.userPreferences) ?? SharedStore.defaults?.data(forKey: SharedStore.Keys.userPreferences)
        guard let data = rawData,
              var prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences.default
        }
        if prefs.isDemoMode {
            prefs.isDemoMode = false
            save(prefs)
        }
        return prefs
    }
}
